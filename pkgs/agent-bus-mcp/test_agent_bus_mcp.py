"""Self-check for the parts that are not one-liners: cursor storage and event shaping.

Deliberately no network and no MCP harness — the tools are thin wrappers over
httpx, but the cursor bookkeeping is the thing that would silently re-read a
room from the beginning, or silently skip messages, if it broke.
"""

import importlib.util
import os
import sys
import tempfile

with tempfile.TemporaryDirectory() as tmp:
    os.environ["STATE_DIRECTORY"] = tmp
    os.environ["AGENT_BUS_NAME"] = "agent-test"

    # In the nix build the test and the module are separate store paths, so
    # "next to me" is /nix/store and wrong; the derivation passes the real path.
    module = os.environ.get(
        "AGENT_BUS_MODULE",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "agent_bus_mcp.py"),
    )
    spec = importlib.util.spec_from_file_location("agent_bus_mcp", module)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)

    # An agent that has never read a room has no mark, so read_new starts from
    # the beginning rather than from "now".
    assert m._get_cursor("agent-test", "!r:x") is None

    m._set_cursor("agent-test", "!r:x", "t1")
    assert m._get_cursor("agent-test", "!r:x") == "t1"

    # Advancing must overwrite, not accumulate: the PRIMARY KEY conflict clause
    # is what stops a second read inserting a duplicate row and the cursor
    # becoming ambiguous.
    m._set_cursor("agent-test", "!r:x", "t2")
    assert m._get_cursor("agent-test", "!r:x") == "t2"

    # Cursors are per agent and per room. Sharing one would make one agent's
    # read hide messages from another.
    assert m._get_cursor("other-agent", "!r:x") is None
    assert m._get_cursor("agent-test", "!other:x") is None

    # Event shaping: a threaded message keeps its root so an agent can reply
    # into the same thread; a plain one reports None rather than raising.
    threaded = m._format(
        {
            "sender": "@a:x",
            "origin_server_ts": 1,
            "event_id": "$e",
            "content": {
                "body": "hi",
                "m.relates_to": {"rel_type": "m.thread", "event_id": "$root"},
            },
        }
    )
    assert threaded == {
        "from": "@a:x",
        "at": 1,
        "text": "hi",
        "event_id": "$e",
        "thread": "$root",
    }, threaded

    plain = m._format(
        {
            "sender": "@b:x",
            "origin_server_ts": 2,
            "event_id": "$f",
            "content": {"body": "yo"},
        }
    )
    assert plain["thread"] is None and plain["text"] == "yo"

    # A malformed event must not take the whole read down.
    assert m._format({})["text"] == ""

print("agent-bus-mcp self-check passed", file=sys.stderr)
