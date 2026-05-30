"""Direct async httpx clients for the *arr REST APIs.

The bot bypasses the three MCP servers (plex-mcp / arr-suite-mcp /
audiobook-mcp) — those exist for Claude Code on the workstation. For the
bot, going direct to the underlying REST APIs is one fewer hop on the
same host, with no MCP-stdio bridge to maintain.

API-version quirks we have to know about:
  - Sonarr / Radarr use /api/v3
  - Prowlarr / Overseerr use /api/v1
Lidarr music is deferred for Phase 1 (no menu/NL surface for music yet).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any, Optional

import httpx


logger = logging.getLogger(__name__)


@dataclass
class ArrEndpoint:
    base_url: str
    api_key: str
    api_version: str  # "v1" or "v3"


@dataclass
class ArrEndpoints:
    sonarr: ArrEndpoint
    radarr: ArrEndpoint
    prowlarr: ArrEndpoint
    overseerr: ArrEndpoint
    plex_token: str = ""
    plex_url: str = "http://localhost:32400"
    abs_token: str = ""
    abs_url: str = "http://localhost:13378"


def endpoints_from_env(env: dict[str, str]) -> ArrEndpoints:
    """Build endpoint config from the agenix-supplied environment dict.

    Required keys: SONARR_API_KEY, RADARR_API_KEY, PROWLARR_API_KEY,
    OVERSEERR_API_KEY. Everything else has sensible localhost defaults.
    """
    return ArrEndpoints(
        sonarr=ArrEndpoint(
            base_url=env.get("SONARR_URL", "http://localhost:8989"),
            api_key=env["SONARR_API_KEY"],
            api_version="v3",
        ),
        radarr=ArrEndpoint(
            base_url=env.get("RADARR_URL", "http://localhost:7878"),
            api_key=env["RADARR_API_KEY"],
            api_version="v3",
        ),
        prowlarr=ArrEndpoint(
            base_url=env.get("PROWLARR_URL", "http://localhost:9696"),
            api_key=env["PROWLARR_API_KEY"],
            api_version="v1",
        ),
        overseerr=ArrEndpoint(
            base_url=env.get("OVERSEERR_URL", "http://localhost:5055"),
            api_key=env["OVERSEERR_API_KEY"],
            api_version="v1",
        ),
        plex_token=env.get("PLEX_TOKEN", ""),
        plex_url=env.get("PLEX_URL", "http://localhost:32400"),
        abs_token=env.get("ABS_TOKEN", ""),
        abs_url=env.get("ABS_URL", "http://localhost:13378"),
    )


class ArrClient:
    """Aggregate httpx client for the *arr stack + Plex + ABS link helpers."""

    def __init__(self, endpoints: ArrEndpoints, timeout: float = 30.0):
        self._endpoints = endpoints
        self._client = httpx.AsyncClient(timeout=timeout)

    async def aclose(self) -> None:
        await self._client.aclose()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        await self.aclose()

    async def _request(
        self,
        endpoint: ArrEndpoint,
        method: str,
        path: str,
        *,
        params: Optional[dict] = None,
        json: Optional[dict] = None,
    ) -> Any:
        url = f"{endpoint.base_url}/api/{endpoint.api_version}/{path.lstrip('/')}"
        headers = {"X-Api-Key": endpoint.api_key, "Accept": "application/json"}
        try:
            resp = await self._client.request(
                method, url, params=params, json=json, headers=headers
            )
            resp.raise_for_status()
            if not resp.content:
                return None
            return resp.json()
        except httpx.HTTPStatusError as e:
            logger.error(
                "%s %s -> %s: %s",
                method,
                url,
                e.response.status_code,
                e.response.text[:200],
            )
            raise
        except httpx.RequestError as e:
            logger.error("%s %s connection error: %s", method, url, e)
            raise

    # -- Sonarr -----------------------------------------------------------

    async def sonarr_lookup(self, query: str) -> list[dict]:
        return (
            await self._request(
                self._endpoints.sonarr,
                "GET",
                "series/lookup",
                params={"term": query},
            )
            or []
        )

    async def sonarr_queue(self) -> list[dict]:
        result = (
            await self._request(
                self._endpoints.sonarr,
                "GET",
                "queue",
                params={"pageSize": 200, "includeUnknownSeriesItems": "true"},
            )
            or {}
        )
        return result.get("records", [])

    async def sonarr_add(self, payload: dict) -> dict:
        return await self._request(
            self._endpoints.sonarr,
            "POST",
            "series",
            json=payload,
        )

    async def sonarr_wanted_missing(self) -> list[dict]:
        result = (
            await self._request(
                self._endpoints.sonarr,
                "GET",
                "wanted/missing",
                params={"pageSize": 50},
            )
            or {}
        )
        return result.get("records", [])

    # -- Radarr -----------------------------------------------------------

    async def radarr_lookup(self, query: str) -> list[dict]:
        return (
            await self._request(
                self._endpoints.radarr,
                "GET",
                "movie/lookup",
                params={"term": query},
            )
            or []
        )

    async def radarr_queue(self) -> list[dict]:
        result = (
            await self._request(
                self._endpoints.radarr,
                "GET",
                "queue",
                params={"pageSize": 200},
            )
            or {}
        )
        return result.get("records", [])

    async def radarr_add(self, payload: dict) -> dict:
        return await self._request(
            self._endpoints.radarr,
            "POST",
            "movie",
            json=payload,
        )

    async def radarr_wanted_missing(self) -> list[dict]:
        result = (
            await self._request(
                self._endpoints.radarr,
                "GET",
                "wanted/missing",
                params={"pageSize": 50},
            )
            or {}
        )
        return result.get("records", [])

    # -- Prowlarr (v1) ----------------------------------------------------

    async def prowlarr_search(
        self,
        query: str,
        categories: Optional[list[int]] = None,
        search_type: str = "search",
    ) -> list[dict]:
        params: dict[str, Any] = {"query": query, "type": search_type}
        if categories:
            params["categories"] = ",".join(map(str, categories))
        return (
            await self._request(
                self._endpoints.prowlarr,
                "GET",
                "search",
                params=params,
            )
            or []
        )

    # -- Overseerr (v1) ---------------------------------------------------

    async def overseerr_request(
        self,
        media_type: str,  # "movie" or "tv"
        tmdb_id: int,
        user_id: Optional[int] = None,
    ) -> dict:
        payload: dict[str, Any] = {"mediaType": media_type, "mediaId": tmdb_id}
        if user_id is not None:
            payload["userId"] = user_id
        return await self._request(
            self._endpoints.overseerr,
            "POST",
            "request",
            json=payload,
        )

    # -- Health probes ----------------------------------------------------

    async def health(self) -> dict[str, bool]:
        """One quick GET per service; returns {service: is_200}."""
        probes = {
            "sonarr": (self._endpoints.sonarr, "system/status"),
            "radarr": (self._endpoints.radarr, "system/status"),
            "prowlarr": (self._endpoints.prowlarr, "system/status"),
            # Overseerr exposes /status not /system/status (matches upstream
            # MCP bug we patched today — see fix(arr-suite-mcp) PR #663).
            "overseerr": (self._endpoints.overseerr, "status"),
        }
        results: dict[str, bool] = {}
        for name, (endpoint, path) in probes.items():
            try:
                await self._request(endpoint, "GET", path)
                results[name] = True
            except Exception:
                results[name] = False
        return results

    # -- Deep-link helpers (no API call) ---------------------------------

    def plex_deep_link(self, rating_key: str) -> str:
        return f"plex://server/details?key=/library/metadata/{rating_key}"

    def abs_item_url(self, item_id: str) -> str:
        return f"{self._endpoints.abs_url}/item/{item_id}"
