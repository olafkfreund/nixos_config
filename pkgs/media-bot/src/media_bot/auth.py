"""Telegram-user whitelist loaded from an agenix-decrypted YAML file.

SIGHUP-triggered reload is wired by main.py (signal handlers must live
inside an asyncio loop, not in this module).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import aiofiles
import yaml


logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class User:
    telegram_id: int
    name: str
    plex_user: str


class Whitelist:
    """In-memory map of Telegram user IDs to mapped Plex usernames.

    The file is reloaded on demand (call `load()`) — main.py invokes this
    on SIGHUP so family members can be added without a NixOS rebuild.
    """

    def __init__(self, path: Path):
        self._path = path
        self._users: dict[int, User] = {}

    async def load(self) -> None:
        try:
            async with aiofiles.open(self._path) as f:
                raw = await f.read()
        except FileNotFoundError:
            logger.error("Whitelist file not found: %s", self._path)
            self._users = {}
            return

        data = yaml.safe_load(raw) or {}
        self._users = {
            u["telegram_id"]: User(
                telegram_id=u["telegram_id"],
                name=u["name"],
                plex_user=u["plex_user"],
            )
            for u in data.get("users", [])
        }
        logger.info("Loaded %d users from %s", len(self._users), self._path)

    def get(self, telegram_id: int) -> Optional[User]:
        return self._users.get(telegram_id)

    def is_authorized(self, telegram_id: int) -> bool:
        return telegram_id in self._users

    def by_plex_user(self, plex_user: str) -> Optional[User]:
        for u in self._users.values():
            if u.plex_user == plex_user:
                return u
        return None

    def all_users(self) -> list[User]:
        return list(self._users.values())
