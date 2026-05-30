"""Entry point — wires Telegram, webhooks, NL, audit into one service.

Runs the python-telegram-bot polling loop and the aiohttp webhook server
concurrently in a single asyncio event loop. SIGHUP triggers whitelist
reload (so family members can be added without a NixOS rebuild). SIGTERM
and SIGINT trigger graceful shutdown.
"""

from __future__ import annotations

import asyncio
import logging
import os
import signal
import sys
from pathlib import Path

from aiohttp import web
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    MessageHandler,
    filters,
)

from .arr_client import ArrClient, endpoints_from_env
from .audit import AuditLog
from .auth import Whitelist
from .buttons import CallbackHandlers
from .menu import MenuHandlers
from .nl import NLHandler
from .tools import Tools
from .webhooks import WebhookServer


logger = logging.getLogger(__name__)


def _required_env(key: str) -> str:
    val = os.environ.get(key)
    if not val:
        print(f"FATAL: env var {key} is required", file=sys.stderr)
        sys.exit(2)
    return val


async def _amain() -> None:
    logging.basicConfig(
        format="%(asctime)s %(name)s %(levelname)s: %(message)s",
        level=logging.INFO,
    )
    # httpx is chatty at INFO; trim
    logging.getLogger("httpx").setLevel(logging.WARNING)

    # -- Configuration --
    token = _required_env("TELEGRAM_BOT_TOKEN")
    users_file = Path(_required_env("BOT_USERS_FILE"))
    state_dir = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/media-bot"))
    ollama_url = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")
    ollama_model = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
    webhook_port = int(os.environ.get("WEBHOOK_PORT", "8090"))

    # -- Components --
    whitelist = Whitelist(users_file)
    await whitelist.load()

    audit = AuditLog(state_dir / "audit.sqlite")
    await audit.open()

    arr = ArrClient(endpoints_from_env(dict(os.environ)))
    tools = Tools(arr)

    nl = NLHandler(
        whitelist=whitelist,
        tools=tools,
        audit=audit,
        ollama_url=ollama_url,
        model=ollama_model,
        history_path=state_dir / "conversations.json",
    )
    await nl.open()

    menu = MenuHandlers(arr, whitelist, audit)
    callbacks = CallbackHandlers(arr, whitelist, audit)

    # -- Telegram application --
    application = Application.builder().token(token).build()
    application.add_handler(CommandHandler("start", menu.start))
    application.add_handler(CommandHandler("help", menu.help_command))
    application.add_handler(CommandHandler("search", menu.search))
    application.add_handler(CommandHandler("add", menu.add))
    application.add_handler(CommandHandler("queue", menu.queue))
    application.add_handler(CommandHandler("status", menu.status))
    application.add_handler(CommandHandler("recent", menu.recent))
    application.add_handler(CommandHandler("wanted", menu.wanted))
    application.add_handler(CallbackQueryHandler(callbacks.handle))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, nl.handle))

    # -- Webhook server --
    webhook_server = WebhookServer(application.bot, whitelist, arr)
    runner = web.AppRunner(webhook_server.app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", webhook_port)

    # -- Signal handlers --
    loop = asyncio.get_running_loop()
    shutdown_event = asyncio.Event()

    def _on_sighup() -> None:
        logger.info("SIGHUP — reloading whitelist")
        loop.create_task(whitelist.load())

    def _on_term(name: str) -> None:
        logger.info("%s — shutting down", name)
        shutdown_event.set()

    loop.add_signal_handler(signal.SIGHUP, _on_sighup)
    loop.add_signal_handler(signal.SIGTERM, lambda: _on_term("SIGTERM"))
    loop.add_signal_handler(signal.SIGINT, lambda: _on_term("SIGINT"))

    # -- Start everything --
    await site.start()
    logger.info("webhook server listening on 0.0.0.0:%d", webhook_port)

    await application.initialize()
    await application.start()
    await application.updater.start_polling()
    logger.info(
        "telegram bot polling started — model=%s, ollama=%s",
        ollama_model,
        ollama_url,
    )

    try:
        await shutdown_event.wait()
    finally:
        logger.info("shutting down…")
        try:
            await application.updater.stop()
        except Exception:  # noqa: BLE001
            pass
        try:
            await application.stop()
        except Exception:  # noqa: BLE001
            pass
        try:
            await application.shutdown()
        except Exception:  # noqa: BLE001
            pass
        await runner.cleanup()
        await nl.aclose()
        await arr.aclose()
        await audit.close()
        logger.info("bye")


def main() -> None:
    """Entry point referenced by pyproject [project.scripts]."""
    try:
        asyncio.run(_amain())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
