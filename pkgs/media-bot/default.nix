# media-bot — household Telegram bot for the *arr stack on p510.
#
# Design spec: see docs/plans/2026-05-30-media-bot-design.md (mirrored into
# the conversation's plan file). Phase 1 surface:
#   • menu commands (/search /add /queue /status /recent /wanted)
#   • Ollama-backed natural-language fallback (function calling on a local
#     LLM running on p510 — no cloud)
#   • webhook receiver exposing /sonarr /radarr /overseerr /audiobook on
#     :8090 with inline action buttons in the resulting Telegram messages
#
# Talks DIRECTLY to *arr/Plex/Audiobookshelf REST APIs via httpx — does NOT
# go through the three existing MCP servers (those keep serving Claude Code
# on the workstation unchanged).
{ lib
, python3Packages
}:

python3Packages.buildPythonApplication {
  pname = "media-bot";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    python-telegram-bot
    httpx
    aiohttp
    aiosqlite
    aiofiles
    pyyaml
    pydantic
  ];

  # No test suite yet (Phase 1 ships without — covered by manual end-to-end
  # per the design's verification section).
  doCheck = false;

  # Import-check the modules that exist so far. Add to this list as new
  # modules are committed in subsequent commits.
  pythonImportsCheck = [
    "media_bot"
    "media_bot.auth"
    "media_bot.arr_client"
    "media_bot.audit"
    "media_bot.menu"
    "media_bot.webhooks"
    "media_bot.buttons"
    "media_bot.tools"
    "media_bot.nl"
    "media_bot.main"
  ];

  meta = {
    description = "Telegram bot front-end for the household media stack (Sonarr/Radarr/Plex/Audiobookshelf) with local-LLM (Ollama) natural-language fallback";
    homepage = "https://github.com/olafkfreund/nixos_config";
    license = lib.licenses.mit;
    mainProgram = "media-bot";
    platforms = lib.platforms.linux;
  };
}
