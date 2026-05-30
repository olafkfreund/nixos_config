"""Ollama-backed natural-language fallback path.

When a Telegram message isn't a slash command, it lands here:

  1. Build a chat completion request to the local Ollama endpoint
     (`http://localhost:11434/v1/chat/completions` — OpenAI-compatible).
  2. Ollama returns either plain text OR a list of tool calls.
  3. If tool calls: execute them via Tools.call(), append results, loop.
  4. Cap at MAX_TOOL_CALLS_PER_TURN to prevent runaway loops.
  5. Reply with the final assistant text.

Rate-limited 1 NL request per 30s per Telegram user.
Conversation memory: rolling 5-turn window per user, persisted to JSON.
Failure mode: Ollama unreachable → documented offline reply; menu commands
keep working independently.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from collections import defaultdict, deque
from pathlib import Path
from typing import Any, Optional

import aiofiles
import httpx
from telegram import Update
from telegram.ext import ContextTypes

from .audit import AuditLog
from .auth import User, Whitelist
from .tools import TOOL_DEFS, Tools


logger = logging.getLogger(__name__)


MAX_TOOL_CALLS_PER_TURN = 5
MAX_CONVERSATION_TURNS = 5  # user + assistant = 2 messages per turn
RATE_LIMIT_SECONDS = 30
OLLAMA_TIMEOUT = 120.0  # function-calling loops can be slow

OFFLINE_REPLY = (
    "I can search and add with commands, but my natural-language brain is "
    "offline — try /help for the command list."
)


def _system_prompt(user_name: str) -> str:
    return (
        f"You are {user_name}'s household media assistant on a Telegram chat. "
        "You can search and add movies and TV shows, check the download queue, "
        "the wanted/missing list, and service health. Keep replies short — "
        "this is a chat, not a chatbot demo. When the user wants something "
        "added, call the appropriate tool. When they ask what's happening, "
        "call get_queue or service_status. Never invent IDs or fabricate data "
        "— call tools to get real information."
    )


class NLHandler:
    """One instance shared across all whitelisted users. Rate-limit and
    conversation memory are keyed per Telegram user ID."""

    def __init__(
        self,
        whitelist: Whitelist,
        tools: Tools,
        audit: AuditLog,
        ollama_url: str,
        model: str,
        history_path: Path,
    ):
        self._whitelist = whitelist
        self._tools = tools
        self._audit = audit
        self._ollama_url = ollama_url.rstrip("/")
        self._model = model
        self._history_path = history_path
        self._client = httpx.AsyncClient(timeout=OLLAMA_TIMEOUT)

        self._last_request: dict[int, float] = {}
        self._history: dict[int, deque[dict[str, Any]]] = defaultdict(
            lambda: deque(maxlen=MAX_CONVERSATION_TURNS * 2)
        )

    async def open(self) -> None:
        await self._load_history()

    async def aclose(self) -> None:
        await self._save_history()
        await self._client.aclose()

    # -- Telegram entry point -------------------------------------------

    async def handle(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None or update.effective_user is None:
            return
        user = self._whitelist.get(update.effective_user.id)
        if user is None:
            return  # silent drop
        text = (update.message.text or "").strip()
        if not text:
            return

        # Rate limit
        now = time.monotonic()
        last = self._last_request.get(user.telegram_id, 0.0)
        if now - last < RATE_LIMIT_SECONDS:
            wait = int(RATE_LIMIT_SECONDS - (now - last))
            await update.message.reply_text(
                f"Still working on your last request — give it about {wait}s."
            )
            return
        self._last_request[user.telegram_id] = now

        # Show typing while the model thinks. Best-effort.
        if update.effective_chat is not None:
            try:
                await update.effective_chat.send_chat_action(action="typing")
            except Exception:  # noqa: BLE001
                pass

        t0 = time.monotonic()
        try:
            reply = await self._chat(user, text)
            result = "ok"
        except httpx.RequestError as e:
            logger.warning("Ollama unreachable: %s", e)
            reply = OFFLINE_REPLY
            result = "ollama-unreachable"
        except httpx.HTTPStatusError as e:
            logger.warning(
                "Ollama returned %s: %s", e.response.status_code, e.response.text[:200]
            )
            reply = OFFLINE_REPLY
            result = f"ollama-{e.response.status_code}"
        except Exception as e:  # noqa: BLE001
            logger.exception("NL handler failed")
            reply = f"Sorry — something broke processing that: {e}"
            result = f"error: {e}"

        await update.message.reply_text(reply)

        await self._audit.log(
            user.telegram_id,
            user.name,
            "nl",
            args={"text_len": len(text)},
            result=result,
            latency_ms=int((time.monotonic() - t0) * 1000),
        )

    # -- Function-calling loop ------------------------------------------

    async def _chat(self, user: User, user_text: str) -> str:
        hist = self._history[user.telegram_id]

        messages: list[dict[str, Any]] = [
            {"role": "system", "content": _system_prompt(user.name)},
        ]
        messages.extend(hist)
        messages.append({"role": "user", "content": user_text})

        tool_calls_made = 0
        final_text = ""

        # +1 so the LAST iteration after MAX_TOOL_CALLS_PER_TURN tool calls
        # can still produce a final text reply.
        for _ in range(MAX_TOOL_CALLS_PER_TURN + 1):
            payload = {
                "model": self._model,
                "messages": messages,
                "tools": TOOL_DEFS,
                "tool_choice": "auto",
            }
            resp = await self._client.post(
                f"{self._ollama_url}/v1/chat/completions",
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()

            msg = data["choices"][0]["message"]
            tool_calls = msg.get("tool_calls") or []

            # Append assistant message to running context. Per OpenAI spec,
            # an assistant message with tool_calls may have content=None.
            assistant_entry: dict[str, Any] = {
                "role": "assistant",
                "content": msg.get("content") or "",
            }
            if tool_calls:
                assistant_entry["tool_calls"] = tool_calls
            messages.append(assistant_entry)

            if not tool_calls:
                final_text = msg.get("content") or ""
                break

            # Execute each tool call requested by the model this turn.
            for tc in tool_calls:
                tool_calls_made += 1
                if tool_calls_made > MAX_TOOL_CALLS_PER_TURN:
                    final_text = (
                        "I'm using too many tools — give me a more specific "
                        "request and I'll try again."
                    )
                    break

                name = tc.get("function", {}).get("name", "")
                args_raw = tc.get("function", {}).get("arguments") or "{}"
                try:
                    args = (
                        json.loads(args_raw)
                        if isinstance(args_raw, str)
                        else (args_raw or {})
                    )
                except json.JSONDecodeError:
                    args = {}

                try:
                    result_obj = await self._tools.call(name, args)
                    result_str = json.dumps(result_obj, default=str)[:4000]
                except Exception as e:  # noqa: BLE001
                    result_str = json.dumps({"error": str(e)})

                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.get("id", ""),
                        "content": result_str,
                    }
                )

            if tool_calls_made > MAX_TOOL_CALLS_PER_TURN:
                break

        if not final_text:
            final_text = "(no reply — try rephrasing)"

        # Update rolling history: this user msg + the final assistant reply.
        # Tool-call mechanics stay out of history (keeps next turn lean).
        hist.append({"role": "user", "content": user_text})
        hist.append({"role": "assistant", "content": final_text})
        await self._save_history()

        return final_text

    # -- Conversation history persistence -------------------------------

    async def _load_history(self) -> None:
        try:
            async with aiofiles.open(self._history_path) as f:
                raw = await f.read()
        except FileNotFoundError:
            return
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("conversation history corrupt; starting fresh")
            return
        for tid_str, turns in data.items():
            try:
                tid = int(tid_str)
            except ValueError:
                continue
            self._history[tid] = deque(turns, maxlen=MAX_CONVERSATION_TURNS * 2)

    async def _save_history(self) -> None:
        self._history_path.parent.mkdir(parents=True, exist_ok=True)
        snapshot = {str(k): list(v) for k, v in self._history.items()}
        async with aiofiles.open(self._history_path, "w") as f:
            await f.write(json.dumps(snapshot))
