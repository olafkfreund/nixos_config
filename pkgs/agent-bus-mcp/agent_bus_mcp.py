"""Shared room for coding agents, over MCP, backed by Matrix.

Four tools. An agent posts what it learned, reads what it missed, and moves on.
That is the whole product.

Why cursors and not a subscription: agents act in turns, not continuously. An
agent is never sitting in a channel waiting to be spoken to — it wakes, does
work, and stops. So the useful question is "what happened since I last looked",
not "am I connected". `read_new` answers exactly that and advances a stored
pointer, which is why this replaced an IRC design whose history was RAM-only
and presence-based.

Why Matrix underneath rather than our own table: humans get a real client
looking at the same rooms. One store, two faces.
"""

import json
import os
import sqlite3
import uuid
from pathlib import Path
from urllib.parse import quote
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

HOMESERVER = os.environ.get("MATRIX_HOMESERVER", "http://127.0.0.1:6167")
ACCESS_TOKEN = os.environ.get("MATRIX_ACCESS_TOKEN", "")
AGENT_NAME = os.environ.get("AGENT_BUS_NAME", "unknown-agent")
STATE_DIR = Path(os.environ.get("STATE_DIRECTORY", "."))

# Only m.room.message. Membership changes, state events and receipts are noise
# to an agent trying to read a conversation.
MESSAGE_FILTER = json.dumps({"types": ["m.room.message"]})

mcp = FastMCP("agent-bus")


def _db() -> sqlite3.Connection:
    conn = sqlite3.connect(STATE_DIR / "cursors.db")
    conn.execute(
        "CREATE TABLE IF NOT EXISTS cursors ("
        " agent TEXT NOT NULL, room TEXT NOT NULL, token TEXT NOT NULL,"
        " PRIMARY KEY (agent, room))"
    )
    return conn


def _get_cursor(agent: str, room: str) -> str | None:
    with _db() as conn:
        row = conn.execute(
            "SELECT token FROM cursors WHERE agent = ? AND room = ?", (agent, room)
        ).fetchone()
    return row[0] if row else None


def _set_cursor(agent: str, room: str, token: str) -> None:
    with _db() as conn:
        conn.execute(
            "INSERT INTO cursors (agent, room, token) VALUES (?, ?, ?)"
            " ON CONFLICT (agent, room) DO UPDATE SET token = excluded.token",
            (agent, room, token),
        )


def _client() -> httpx.Client:
    if not ACCESS_TOKEN:
        raise RuntimeError("MATRIX_ACCESS_TOKEN is unset; the bus has no identity")
    return httpx.Client(
        base_url=f"{HOMESERVER}/_matrix/client/v3",
        headers={"Authorization": f"Bearer {ACCESS_TOKEN}"},
        timeout=30.0,
    )


def _resolve(client: httpx.Client, room: str) -> str:
    """Accept a room id, or an alias like #agents:example.com.

    The alias must be percent-encoded into the path: it contains "#" and ":",
    both of which otherwise truncate the URL and leave the server looking up
    an empty alias.
    """
    if room.startswith("!"):
        return room
    alias = room if room.startswith("#") else f"#{room}"
    r = client.get("/directory/room/" + quote(alias, safe=""))
    r.raise_for_status()
    return r.json()["room_id"]


def _format(event: dict[str, Any]) -> dict[str, Any]:
    content = event.get("content", {})
    return {
        "from": event.get("sender", ""),
        "at": event.get("origin_server_ts", 0),
        "text": content.get("body", ""),
        "event_id": event.get("event_id", ""),
        "thread": content.get("m.relates_to", {}).get("event_id"),
    }


@mcp.tool()
def post(room: str, text: str, thread: str | None = None) -> str:
    """Post a message to a room. Pass `thread` (an event id) to reply in a thread.

    Worth posting: a gotcha with its cause, a decision with its reasoning, a
    dead end you ruled out. Not worth posting: routine progress.
    """
    body: dict[str, Any] = {"msgtype": "m.text", "body": text}
    if thread:
        body["m.relates_to"] = {
            "rel_type": "m.thread",
            "event_id": thread,
            "is_falling_back": True,
        }
    with _client() as client:
        room_id = _resolve(client, room)
        # The transaction id makes a retried PUT idempotent: the server returns
        # the original event_id instead of posting twice. A fresh uuid per call
        # is correct precisely because we never retry inside this function.
        txn = uuid.uuid4().hex
        r = client.put(f"/rooms/{room_id}/send/m.room.message/{txn}", json=body)
        r.raise_for_status()
        return f"posted to {room} as {AGENT_NAME}: {r.json()['event_id']}"


@mcp.tool()
def read_new(room: str, limit: int = 100) -> str:
    """Everything said in a room since this agent last read it. Advances the cursor.

    First call returns recent history and sets the mark; later calls return
    only what is new, so calling it twice in a row is empty rather than a
    repeat.
    """
    with _client() as client:
        room_id = _resolve(client, room)
        params: dict[str, Any] = {
            "dir": "f",
            "limit": limit,
            "filter": MESSAGE_FILTER,
        }
        cursor = _get_cursor(AGENT_NAME, room_id)
        if cursor:
            params["from"] = cursor
        r = client.get(f"/rooms/{room_id}/messages", params=params)
        r.raise_for_status()
        payload = r.json()

    # `end` is absent once there is nothing further; keep the old mark so the
    # next call does not re-read the room from the beginning.
    if payload.get("end"):
        _set_cursor(AGENT_NAME, room_id, payload["end"])

    messages = [_format(e) for e in payload.get("chunk", [])]
    if not messages:
        return f"nothing new in {room}"
    return json.dumps(messages, indent=2)


@mcp.tool()
def list_rooms() -> str:
    """Rooms this agent is in, with their names."""
    out = []
    with _client() as client:
        r = client.get("/joined_rooms")
        r.raise_for_status()
        for room_id in r.json().get("joined_rooms", []):
            name = client.get(f"/rooms/{room_id}/state/m.room.name/")
            out.append(
                {
                    "room_id": room_id,
                    "name": name.json().get("name")
                    if name.status_code == 200
                    else None,
                }
            )
    return json.dumps(out, indent=2)


@mcp.tool()
def search(query: str, room: str | None = None) -> str:
    """Full-text search across messages. Check here before asking a question.

    Token matching, not fuzzy — search for a distinctive word rather than a
    phrase you half-remember.
    """
    criteria: dict[str, Any] = {"search_term": query, "order_by": "recent"}
    with _client() as client:
        if room:
            criteria["filter"] = {"rooms": [_resolve(client, room)]}
        r = client.post(
            "/search",
            json={"search_categories": {"room_events": criteria}},
        )
        r.raise_for_status()
        results = r.json()["search_categories"]["room_events"]

    hits = [_format(item["result"]) for item in results.get("results", [])]
    if not hits:
        return f"no matches for {query!r}"
    return json.dumps(
        {"count": results.get("count", len(hits)), "hits": hits}, indent=2
    )


if __name__ == "__main__":
    mcp.run()
