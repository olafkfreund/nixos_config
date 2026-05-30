"""aiohttp webhook receiver mounted on :8090.

Sonarr / Radarr / Overseerr / audiobook-import.service POST events here;
we filter to the Quiet event set (per design spec) and push curated
Telegram messages with inline action buttons.
"""

from __future__ import annotations

import logging
from typing import Optional

from aiohttp import web
from telegram import Bot, InlineKeyboardButton, InlineKeyboardMarkup

from .arr_client import ArrClient
from .auth import Whitelist


logger = logging.getLogger(__name__)


class WebhookServer:
    def __init__(self, bot: Bot, whitelist: Whitelist, arr: ArrClient):
        self._bot = bot
        self._whitelist = whitelist
        self._arr = arr

        self._app = web.Application()
        self._app.router.add_post("/sonarr", self._handle_sonarr)
        self._app.router.add_post("/radarr", self._handle_radarr)
        self._app.router.add_post("/overseerr", self._handle_overseerr)
        self._app.router.add_post("/audiobook", self._handle_audiobook)
        self._app.router.add_get("/health", self._handle_health)

    @property
    def app(self) -> web.Application:
        return self._app

    # -- Sending helpers --------------------------------------------------

    async def _broadcast(
        self, text: str, keyboard: Optional[InlineKeyboardMarkup] = None
    ) -> None:
        for user in self._whitelist.all_users():
            try:
                await self._bot.send_message(
                    chat_id=user.telegram_id,
                    text=text,
                    parse_mode="Markdown",
                    reply_markup=keyboard,
                )
            except Exception as e:  # noqa: BLE001
                logger.warning("send to telegram_id=%s failed: %s", user.telegram_id, e)

    async def _send(
        self,
        telegram_id: int,
        text: str,
        keyboard: Optional[InlineKeyboardMarkup] = None,
    ) -> None:
        try:
            await self._bot.send_message(
                chat_id=telegram_id,
                text=text,
                parse_mode="Markdown",
                reply_markup=keyboard,
            )
        except Exception as e:  # noqa: BLE001
            logger.warning("send to telegram_id=%s failed: %s", telegram_id, e)

    # -- Health -----------------------------------------------------------

    async def _handle_health(self, _request: web.Request) -> web.Response:
        return web.json_response({"status": "ok"})

    # -- Sonarr -----------------------------------------------------------

    async def _handle_sonarr(self, request: web.Request) -> web.Response:
        try:
            payload = await request.json()
        except Exception:
            return web.Response(status=400, text="invalid-json")

        event = payload.get("eventType", "")
        if event == "Test":
            await self._broadcast("✅ Sonarr webhook test received.")
            return web.Response(text="ok")
        # Quiet set: only EpisodeImported
        if event != "EpisodeImported":
            return web.Response(text="ignored")

        series_title = (payload.get("series") or {}).get("title", "?")
        episodes = payload.get("episodes") or []
        if not episodes:
            return web.Response(text="no-episodes")

        ep0 = episodes[0]
        season = ep0.get("seasonNumber", 0)
        episode = ep0.get("episodeNumber", 0)
        ep_title = ep0.get("title", "")
        title_str = f"S{season:02d}E{episode:02d}"
        if len(episodes) > 1:
            title_str += f" (+{len(episodes) - 1} more)"

        # TODO: deep-link to specific episode in Plex. Sonarr's webhook
        # doesn't include a Plex ratingKey; we'd have to look it up via Plex
        # search after import. Deferred to Phase 2.
        kb = InlineKeyboardMarkup(
            [[InlineKeyboardButton("▶ Open Plex", url="plex://")]]
        )

        text = f"\U0001f4fa *Imported:* {series_title} — {title_str}"
        if ep_title and len(episodes) == 1:
            text += f"\n_{ep_title}_"
        await self._broadcast(text, kb)
        return web.Response(text="ok")

    # -- Radarr -----------------------------------------------------------

    async def _handle_radarr(self, request: web.Request) -> web.Response:
        try:
            payload = await request.json()
        except Exception:
            return web.Response(status=400, text="invalid-json")

        event = payload.get("eventType", "")
        if event == "Test":
            await self._broadcast("✅ Radarr webhook test received.")
            return web.Response(text="ok")
        if event != "MovieImported":
            return web.Response(text="ignored")

        movie = payload.get("movie") or {}
        title = movie.get("title", "?")
        year = movie.get("year", "")

        kb = InlineKeyboardMarkup(
            [[InlineKeyboardButton("▶ Open Plex", url="plex://")]]
        )
        await self._broadcast(f"\U0001f3ac *Imported:* {title} ({year})", kb)
        return web.Response(text="ok")

    # -- Overseerr --------------------------------------------------------

    async def _handle_overseerr(self, request: web.Request) -> web.Response:
        try:
            payload = await request.json()
        except Exception:
            return web.Response(status=400, text="invalid-json")

        notif = payload.get("notification_type", "")
        if notif == "TEST_NOTIFICATION":
            await self._broadcast("✅ Overseerr webhook test received.")
            return web.Response(text="ok")
        # Quiet set: only MEDIA_APPROVED. (MEDIA_PENDING / MEDIA_AVAILABLE
        # deferred for the future verbose preset.)
        if notif != "MEDIA_APPROVED":
            return web.Response(text="ignored")

        subject = payload.get("subject", "?")
        request_info = payload.get("request") or {}
        requester = (
            request_info.get("requestedBy_username")
            or request_info.get("requested_by_email")
            or ""
        )
        user = self._whitelist.by_plex_user(requester) if requester else None

        text = f"✅ *Request approved:* {subject}"
        if user:
            await self._send(user.telegram_id, text)
        else:
            # Fallback: broadcast. Better noise than silence when the
            # plex-user mapping is incomplete.
            logger.info(
                "Overseerr approved for unmapped requester %r; broadcasting",
                requester,
            )
            await self._broadcast(text)
        return web.Response(text="ok")

    # -- Audiobook (custom POST from audiobook-import.service) -----------

    async def _handle_audiobook(self, request: web.Request) -> web.Response:
        try:
            payload = await request.json()
        except Exception:
            return web.Response(status=400, text="invalid-json")

        title = payload.get("title", "?")
        author = payload.get("author") or ""
        item_id = payload.get("item_id") or ""

        text = f"\U0001f3a7 *Audiobook imported:* {title}"
        if author:
            text += f" — _{author}_"

        kb: Optional[InlineKeyboardMarkup] = None
        if item_id:
            kb = InlineKeyboardMarkup(
                [
                    [
                        InlineKeyboardButton(
                            "▶ Open in ABS",
                            url=self._arr.abs_item_url(item_id),
                        )
                    ]
                ]
            )

        await self._broadcast(text, kb)
        return web.Response(text="ok")
