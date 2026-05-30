"""JSON-schema tool definitions for the local-LLM NL path, plus their
runtime implementations.

The tool defs use OpenAI's function-calling JSON-schema format — Ollama's
`/v1/chat/completions` endpoint understands this natively.

Each implementation is a thin shim over `arr_client.py` so the menu path
and the NL path share the same business logic. Audiobook search and
grabbing are deferred — the audiobook-mcp surface isn't reachable from
the bot in Phase 1; menu-/search still works for movies and TV.
"""

from __future__ import annotations

import logging
from typing import Any

from .arr_client import ArrClient
from .buttons import (
    RADARR_QUALITY_PROFILE_ID,
    RADARR_ROOT_FOLDER,
    SONARR_LANGUAGE_PROFILE_ID,
    SONARR_QUALITY_PROFILE_ID,
    SONARR_ROOT_FOLDER,
)


logger = logging.getLogger(__name__)


# Tool schemas in OpenAI function-calling format. Ollama's OpenAI-compat
# endpoint (`/v1/chat/completions`) consumes these directly via the `tools`
# request field.
TOOL_DEFS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "search_movies",
            "description": "Search Radarr for movies by title. Returns up to 5 matches with TMDB IDs.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Movie title or partial title to search for",
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_shows",
            "description": "Search Sonarr for TV shows by title. Returns up to 5 matches with TVDB IDs.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Show title or partial title to search for",
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "add_movie",
            "description": "Add a movie to Radarr by its TMDB ID. Call search_movies first to obtain the ID.",
            "parameters": {
                "type": "object",
                "properties": {
                    "tmdb_id": {
                        "type": "integer",
                        "description": "The TMDB ID of the movie to add",
                    },
                },
                "required": ["tmdb_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "add_show",
            "description": "Add a TV show to Sonarr by its TVDB ID. Call search_shows first to obtain the ID.",
            "parameters": {
                "type": "object",
                "properties": {
                    "tvdb_id": {
                        "type": "integer",
                        "description": "The TVDB ID of the series to add",
                    },
                    "mode": {
                        "type": "string",
                        "enum": ["all", "future"],
                        "description": "Monitor all seasons ('all') or only future episodes ('future'). Default: all.",
                    },
                },
                "required": ["tvdb_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_queue",
            "description": "List items currently downloading in Sonarr and Radarr.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_wanted",
            "description": "Get counts of monitored-but-missing episodes (Sonarr) and movies (Radarr).",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "service_status",
            "description": "Check health of Sonarr, Radarr, Prowlarr, and Overseerr.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]


class Tools:
    """Runtime dispatch for the tools defined in TOOL_DEFS."""

    def __init__(self, arr: ArrClient):
        self._arr = arr

    async def call(self, name: str, args: dict[str, Any]) -> Any:
        """Dispatch a tool call by name. Returns a JSON-serializable result.
        Raises ValueError for unknown tool names; callers should serialize
        the exception as the tool result so the model can recover."""
        if name == "search_movies":
            return await self._search_movies(args.get("query", ""))
        if name == "search_shows":
            return await self._search_shows(args.get("query", ""))
        if name == "add_movie":
            return await self._add_movie(int(args["tmdb_id"]))
        if name == "add_show":
            return await self._add_show(int(args["tvdb_id"]), args.get("mode", "all"))
        if name == "get_queue":
            return await self._get_queue()
        if name == "get_wanted":
            return await self._get_wanted()
        if name == "service_status":
            return await self._service_status()
        raise ValueError(f"unknown tool: {name}")

    # -- Search ----------------------------------------------------------

    async def _search_movies(self, query: str) -> list[dict]:
        hits = await self._arr.radarr_lookup(query)
        return [
            {
                "title": h.get("title"),
                "year": h.get("year"),
                "tmdb_id": h.get("tmdbId"),
                "overview": (h.get("overview") or "")[:300],
            }
            for h in hits[:5]
        ]

    async def _search_shows(self, query: str) -> list[dict]:
        hits = await self._arr.sonarr_lookup(query)
        return [
            {
                "title": h.get("title"),
                "year": h.get("year"),
                "tvdb_id": h.get("tvdbId"),
                "overview": (h.get("overview") or "")[:300],
            }
            for h in hits[:5]
        ]

    # -- Add -------------------------------------------------------------

    async def _add_movie(self, tmdb_id: int) -> dict:
        hits = await self._arr.radarr_lookup(f"tmdb:{tmdb_id}")
        if not hits:
            return {"status": "not_found", "tmdb_id": tmdb_id}
        movie = hits[0]
        payload = {
            "title": movie["title"],
            "tmdbId": movie["tmdbId"],
            "year": movie.get("year"),
            "qualityProfileId": RADARR_QUALITY_PROFILE_ID,
            "rootFolderPath": RADARR_ROOT_FOLDER,
            "monitored": True,
            "addOptions": {"searchForMovie": True},
            "images": movie.get("images", []),
        }
        await self._arr.radarr_add(payload)
        return {"status": "added", "title": movie["title"], "year": movie.get("year")}

    async def _add_show(self, tvdb_id: int, mode: str) -> dict:
        hits = await self._arr.sonarr_lookup(f"tvdb:{tvdb_id}")
        if not hits:
            return {"status": "not_found", "tvdb_id": tvdb_id}
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
        return {"status": "added", "title": series["title"], "mode": mode}

    # -- Status / queue / wanted ----------------------------------------

    async def _get_queue(self) -> dict:
        sonarr = await self._arr.sonarr_queue()
        radarr = await self._arr.radarr_queue()
        return {
            "shows_downloading": [
                {"title": q.get("title"), "status": q.get("status")}
                for q in sonarr[:10]
            ],
            "movies_downloading": [
                {"title": q.get("title"), "status": q.get("status")}
                for q in radarr[:10]
            ],
        }

    async def _get_wanted(self) -> dict:
        sonarr = await self._arr.sonarr_wanted_missing()
        radarr = await self._arr.radarr_wanted_missing()
        return {
            "missing_episodes": len(sonarr),
            "missing_movies": len(radarr),
        }

    async def _service_status(self) -> dict:
        return await self._arr.health()
