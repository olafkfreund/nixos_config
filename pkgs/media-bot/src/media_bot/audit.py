"""Append-only audit log in /var/lib/media-bot/audit.sqlite.

Every menu command and every callback writes one row here. Useful for
debugging (why did the bot do that?), spot-checks ("did Partner search for
anything yesterday?"), and any future per-user analytics.
"""

from __future__ import annotations

import json
import logging
import time
from pathlib import Path
from typing import Any, Optional

import aiosqlite


logger = logging.getLogger(__name__)


SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts INTEGER NOT NULL,
    telegram_id INTEGER NOT NULL,
    name TEXT,
    command TEXT NOT NULL,
    args_json TEXT,
    result TEXT,
    latency_ms INTEGER
);
CREATE INDEX IF NOT EXISTS idx_events_telegram_id ON events(telegram_id);
CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
"""


class AuditLog:
    """Tiny aiosqlite-backed log. Single writer; no locking concerns for our
    family-scale traffic. Each .log() commits immediately so a crash never
    loses more than the in-flight call."""

    def __init__(self, path: Path):
        self._path = path
        self._db: Optional[aiosqlite.Connection] = None

    async def open(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._db = await aiosqlite.connect(str(self._path))
        await self._db.executescript(SCHEMA)
        await self._db.commit()

    async def close(self) -> None:
        if self._db is not None:
            await self._db.close()
            self._db = None

    async def log(
        self,
        telegram_id: int,
        name: Optional[str],
        command: str,
        args: Any = None,
        result: str = "ok",
        latency_ms: Optional[int] = None,
    ) -> None:
        if self._db is None:
            logger.warning(
                "audit not opened; dropping event %s/%s", telegram_id, command
            )
            return
        await self._db.execute(
            "INSERT INTO events (ts, telegram_id, name, command, args_json, result, latency_ms) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                int(time.time()),
                telegram_id,
                name,
                command,
                json.dumps(args, default=str) if args is not None else None,
                result,
                latency_ms,
            ),
        )
        await self._db.commit()
