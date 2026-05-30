"""Slash-command handlers wired into python-telegram-bot's Application.

Auth is silent-drop per the spec: non-whitelisted Telegram updates produce
no response at all (no "you are not authorized" — prevents discovery).
"""

from __future__ import annotations

import logging
import time
from typing import Optional

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import ContextTypes

from .arr_client import ArrClient
from .audit import AuditLog
from .auth import User, Whitelist


logger = logging.getLogger(__name__)


HELP_TEXT = (
    "*Media bot commands*\n\n"
    "Search & add:\n"
    " /search <title> — search movies and TV\n"
    " /add <title> — same as /search; tap a button to add\n\n"
    "Status:\n"
    " /queue — what's downloading right now\n"
    " /wanted — missing episodes / movies\n"
    " /status — service health (Sonarr, Radarr, Prowlarr, Overseerr)\n"
    " /recent — placeholder for Phase 2; for now you'll get notifications "
    "when imports happen\n\n"
    "Plain text — anything that isn't a slash command goes through the local "
    "LLM running on p510 (qwen2.5:7b) which can search, add, and check status "
    "across all services."
)


def _auth(update: Update, whitelist: Whitelist) -> Optional[User]:
    if update.effective_user is None:
        return None
    user = whitelist.get(update.effective_user.id)
    if user is None:
        logger.info(
            "drop update from unauthorized telegram_id=%s",
            update.effective_user.id,
        )
    return user


class MenuHandlers:
    """Owns all slash commands. Constructed once in main.py, methods bound to
    Application as CommandHandler callbacks."""

    def __init__(self, arr: ArrClient, whitelist: Whitelist, audit: AuditLog):
        self._arr = arr
        self._whitelist = whitelist
        self._audit = audit

    # -- /start /help -----------------------------------------------------

    async def start(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        await update.message.reply_text(
            f"Hi {user.name} — type /help for what I can do.",
        )
        await self._audit.log(user.telegram_id, user.name, "/start")

    async def help_command(
        self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE
    ) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        await update.message.reply_text(HELP_TEXT, parse_mode="Markdown")
        await self._audit.log(user.telegram_id, user.name, "/help")

    # -- /search and /add (alias of /search for Phase 1) -----------------

    async def search(self, update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        query = " ".join(ctx.args) if ctx.args else ""
        if not query:
            await update.message.reply_text("Usage: /search <title>")
            return

        t0 = time.monotonic()
        try:
            movies = await self._arr.radarr_lookup(query)
            shows = await self._arr.sonarr_lookup(query)
        except Exception as e:  # noqa: BLE001 — surface anything to chat
            await update.message.reply_text(f"Search failed: {e}")
            await self._audit.log(
                user.telegram_id,
                user.name,
                "/search",
                args={"query": query},
                result=f"error: {e}",
                latency_ms=int((time.monotonic() - t0) * 1000),
            )
            return

        sent = 0
        for m in movies[:3]:
            tmdb = m.get("tmdbId")
            if tmdb is None:
                continue
            title = m.get("title", "?")
            year = m.get("year", "")
            overview = (m.get("overview") or "")[:200]
            kb = InlineKeyboardMarkup(
                [
                    [
                        InlineKeyboardButton(
                            "➕ Add via Radarr",
                            callback_data=f"add:radarr:{tmdb}",
                        )
                    ]
                ]
            )
            await update.message.reply_text(
                f"\U0001f3ac *{title}* ({year})\n_{overview}_",
                parse_mode="Markdown",
                reply_markup=kb,
            )
            sent += 1

        for s in shows[:3]:
            tvdb = s.get("tvdbId")
            if tvdb is None:
                continue
            title = s.get("title", "?")
            year = s.get("year", "")
            overview = (s.get("overview") or "")[:200]
            kb = InlineKeyboardMarkup(
                [
                    [
                        InlineKeyboardButton(
                            "➕ Add (all seasons)",
                            callback_data=f"add:sonarr:{tvdb}:all",
                        )
                    ]
                ]
            )
            await update.message.reply_text(
                f"\U0001f4fa *{title}* ({year})\n_{overview}_",
                parse_mode="Markdown",
                reply_markup=kb,
            )
            sent += 1

        if sent == 0:
            await update.message.reply_text(
                f"No matches for *{query}*.", parse_mode="Markdown"
            )

        await self._audit.log(
            user.telegram_id,
            user.name,
            "/search",
            args={"query": query, "movie_hits": len(movies), "show_hits": len(shows)},
            latency_ms=int((time.monotonic() - t0) * 1000),
        )

    async def add(self, update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
        # Phase 1: /add is an alias for /search. The inline buttons on the
        # search results are the actual add action.
        await self.search(update, ctx)

    # -- /queue -----------------------------------------------------------

    async def queue(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        t0 = time.monotonic()
        try:
            sonarr_q = await self._arr.sonarr_queue()
            radarr_q = await self._arr.radarr_queue()
        except Exception as e:  # noqa: BLE001
            await update.message.reply_text(f"Queue lookup failed: {e}")
            return

        lines: list[str] = []
        for item in sonarr_q[:10]:
            title = item.get("title", "?")
            status = item.get("status", "?")
            size_left = (item.get("sizeleft") or 0) / 1e9
            lines.append(f"\U0001f4fa {title} — {status} ({size_left:.1f}GB left)")
        for item in radarr_q[:10]:
            title = item.get("title", "?")
            status = item.get("status", "?")
            size_left = (item.get("sizeleft") or 0) / 1e9
            lines.append(f"\U0001f3ac {title} — {status} ({size_left:.1f}GB left)")

        if not lines:
            await update.message.reply_text("Queue is empty.")
        else:
            await update.message.reply_text(
                "*Queue:*\n" + "\n".join(lines), parse_mode="Markdown"
            )

        await self._audit.log(
            user.telegram_id,
            user.name,
            "/queue",
            latency_ms=int((time.monotonic() - t0) * 1000),
        )

    # -- /status ----------------------------------------------------------

    async def status(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        t0 = time.monotonic()
        health = await self._arr.health()
        lines = [f"{'✅' if ok else '❌'} {svc}" for svc, ok in health.items()]
        await update.message.reply_text(
            "*Service status:*\n" + "\n".join(lines), parse_mode="Markdown"
        )
        await self._audit.log(
            user.telegram_id,
            user.name,
            "/status",
            latency_ms=int((time.monotonic() - t0) * 1000),
        )

    # -- /recent ---------------------------------------------------------

    async def recent(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        # The *arr APIs don't have a clean "imported in the last 24h" query;
        # would require pagination through history or a date-filtered call.
        # Deferred to Phase 2 — the webhook fabric already pushes import
        # notifications as they happen.
        await update.message.reply_text(
            "Recent-imports view ships in Phase 2 — for now you get notifications "
            "when imports happen.",
        )
        await self._audit.log(user.telegram_id, user.name, "/recent")

    # -- /wanted ---------------------------------------------------------

    async def wanted(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        user = _auth(update, self._whitelist)
        if user is None or update.message is None:
            return
        t0 = time.monotonic()
        try:
            sonarr_w = await self._arr.sonarr_wanted_missing()
            radarr_w = await self._arr.radarr_wanted_missing()
        except Exception as e:  # noqa: BLE001
            await update.message.reply_text(f"Wanted lookup failed: {e}")
            return

        lines = [
            f"\U0001f4fa {len(sonarr_w)} missing episode"
            f"{'s' if len(sonarr_w) != 1 else ''}",
            f"\U0001f3ac {len(radarr_w)} missing movie"
            f"{'s' if len(radarr_w) != 1 else ''}",
        ]
        for ep in sonarr_w[:5]:
            series = (ep.get("series") or {}).get("title", "?")
            season = ep.get("seasonNumber", 0)
            episode = ep.get("episodeNumber", 0)
            lines.append(f"  · {series} S{season:02d}E{episode:02d}")
        for m in radarr_w[:5]:
            lines.append(f"  · {m.get('title', '?')}")

        await update.message.reply_text(
            "*Wanted (missing):*\n" + "\n".join(lines), parse_mode="Markdown"
        )
        await self._audit.log(
            user.telegram_id,
            user.name,
            "/wanted",
            args={"shows": len(sonarr_w), "movies": len(radarr_w)},
            latency_ms=int((time.monotonic() - t0) * 1000),
        )
