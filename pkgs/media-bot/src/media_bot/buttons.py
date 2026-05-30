"""Inline-button callback router.

Callback data uses a compact `action:arg1:arg2:...` scheme:

  add:radarr:<tmdb_id>           — add a movie
  add:sonarr:<tvdb_id>:<mode>    — add a series; mode is "all" or "future"
  watch:<rating_key>             — return a plex:// deep link (Phase 2)

Phase-1 defaults for qualityProfileId / rootFolderPath come from env vars
(`RADARR_ROOT_FOLDER`, `RADARR_QUALITY_PROFILE_ID`, `SONARR_*`); proper
discovery via the `/rootfolder` endpoint is deferred.
"""

from __future__ import annotations

import logging
import os
import time

from telegram import Update
from telegram.ext import ContextTypes

from .arr_client import ArrClient
from .audit import AuditLog
from .auth import Whitelist


logger = logging.getLogger(__name__)


# Env-tunable defaults. Picked to match the existing p510 storage layout
# (per the design doc's storage tree).
RADARR_ROOT_FOLDER = os.environ.get("RADARR_ROOT_FOLDER", "/mnt/media/Media/Movies")
RADARR_QUALITY_PROFILE_ID = int(os.environ.get("RADARR_QUALITY_PROFILE_ID", "1"))
SONARR_ROOT_FOLDER = os.environ.get("SONARR_ROOT_FOLDER", "/mnt/media/Media/TV")
SONARR_QUALITY_PROFILE_ID = int(os.environ.get("SONARR_QUALITY_PROFILE_ID", "1"))
SONARR_LANGUAGE_PROFILE_ID = int(os.environ.get("SONARR_LANGUAGE_PROFILE_ID", "1"))


class CallbackHandlers:
    def __init__(self, arr: ArrClient, whitelist: Whitelist, audit: AuditLog):
        self._arr = arr
        self._whitelist = whitelist
        self._audit = audit

    async def handle(self, update: Update, _ctx: ContextTypes.DEFAULT_TYPE) -> None:
        query = update.callback_query
        if query is None or update.effective_user is None:
            return
        await query.answer()  # ack the spinner

        user = self._whitelist.get(update.effective_user.id)
        if user is None:
            return  # silent drop

        data = query.data or ""
        parts = data.split(":")
        if not parts:
            return
        action = parts[0]

        t0 = time.monotonic()
        result = "ok"
        try:
            if action == "add" and len(parts) >= 3:
                await self._handle_add(query, parts[1], parts[2:])
            elif action == "watch":
                # Plex deep-link without ratingKey. Phase 2 should look up
                # the rating key via Plex search after each import.
                await query.message.reply_text(
                    "Plex deep links ship in Phase 2 — for now open Plex manually.",
                )
            else:
                await query.message.reply_text(f"Unknown action: {action}")
                result = "unknown-action"
        except Exception as e:  # noqa: BLE001
            logger.exception("callback %s failed", data)
            await query.message.reply_text(f"Action failed: {e}")
            result = f"error: {e}"

        await self._audit.log(
            user.telegram_id,
            user.name,
            f"callback:{action}",
            args={"data": data},
            result=result,
            latency_ms=int((time.monotonic() - t0) * 1000),
        )

    # -- add:radarr / add:sonarr -----------------------------------------

    async def _handle_add(self, query, kind: str, args: list[str]) -> None:
        if kind == "radarr":
            tmdb_id = int(args[0])
            hits = await self._arr.radarr_lookup(f"tmdb:{tmdb_id}")
            if not hits:
                await query.message.reply_text("Movie not found via Radarr lookup.")
                return
            movie = hits[0]
            payload = {
                "title": movie["title"],
                "tmdbId": movie["tmdbId"],
                "year": movie.get("year"),
                "qualityProfileId": RADARR_QUALITY_PROFILE_ID,
                "rootFolderPath": RADARR_ROOT_FOLDER,
                "monitored": True,
                "addOptions": {"searchForMovie": True},
                # 'images' is sometimes required; pass through if present
                "images": movie.get("images", []),
            }
            await self._arr.radarr_add(payload)
            await query.message.reply_text(
                f"\U0001f3ac Added: *{movie['title']}*", parse_mode="Markdown"
            )

        elif kind == "sonarr":
            tvdb_id = int(args[0])
            mode = args[1] if len(args) > 1 else "all"
            hits = await self._arr.sonarr_lookup(f"tvdb:{tvdb_id}")
            if not hits:
                await query.message.reply_text("Series not found via Sonarr lookup.")
                return
            series = hits[0]
            payload = {
                "title": series["title"],
                "tvdbId": series["tvdbId"],
                "qualityProfileId": SONARR_QUALITY_PROFILE_ID,
                "languageProfileId": SONARR_LANGUAGE_PROFILE_ID,
                "rootFolderPath": SONARR_ROOT_FOLDER,
                "monitored": True,
                "seasons": series.get("seasons", []),
                "images": series.get("images", []),
                "addOptions": {
                    "monitor": "all" if mode == "all" else "future",
                    "searchForMissingEpisodes": True,
                },
            }
            await self._arr.sonarr_add(payload)
            await query.message.reply_text(
                f"\U0001f4fa Added: *{series['title']}*", parse_mode="Markdown"
            )

        else:
            await query.message.reply_text(f"Unknown add kind: {kind}")
