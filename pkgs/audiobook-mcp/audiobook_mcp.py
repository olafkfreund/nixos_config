"""audiobook-mcp — MCP server for audiobook acquisition + library on p510.

Exposes tools an LLM agent can drive to search two sources (AudioBookBay
torrents and NZBGeek Usenet via Prowlarr), grab the chosen release, and
inspect the Audiobookshelf library. Stdio transport; wrapped by mcp-proxy
into an SSE endpoint in modules/services/audiobook-mcp.nix.

Configuration via environment (URLs have sane localhost defaults; API keys
come from an agenix EnvironmentFile):
  ABB_APP_URL          audiobookbay-automated base URL (default :5078)
  ABB_HOSTNAME         AudioBookBay host (default audiobookbay.lu)
  PROWLARR_URL / PROWLARR_API_KEY
  SABNZBD_URL  / SABNZBD_API_KEY
  ABS_URL      / ABS_API_KEY        (Audiobookshelf; key optional if open)
  USENET_CATEGORIES    Prowlarr category ids (default "3030" = Audiobook)
"""

import os

import httpx
from bs4 import BeautifulSoup
from mcp.server.fastmcp import FastMCP

ABB_APP_URL = os.environ.get("ABB_APP_URL", "http://127.0.0.1:5078").rstrip("/")
ABB_HOSTNAME = os.environ.get("ABB_HOSTNAME", "audiobookbay.lu")
PROWLARR_URL = os.environ.get("PROWLARR_URL", "http://127.0.0.1:9696").rstrip("/")
PROWLARR_API_KEY = os.environ.get("PROWLARR_API_KEY", "")
SABNZBD_URL = os.environ.get("SABNZBD_URL", "http://127.0.0.1:8080").rstrip("/")
SABNZBD_API_KEY = os.environ.get("SABNZBD_API_KEY", "")
ABS_URL = os.environ.get("ABS_URL", "http://127.0.0.1:13378").rstrip("/")
ABS_API_KEY = os.environ.get("ABS_API_KEY", "")
USENET_CATEGORIES = os.environ.get("USENET_CATEGORIES", "3030")

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 audiobook-mcp"

mcp = FastMCP("audiobook-mcp")


def _abs_headers():
    return {"Authorization": f"Bearer {ABS_API_KEY}"} if ABS_API_KEY else {}


@mcp.tool()
def search_abb(query: str, max_pages: int = 1) -> list[dict]:
    """Search AudioBookBay (torrent source) for audiobooks.

    Returns a list of {title, link} where link is the detail-page URL to pass
    to add_abb. Use this for torrent releases; results are not pre-filtered.
    """
    results: list[dict] = []
    q = query.lower().replace(" ", "+")
    with httpx.Client(timeout=20, headers={"User-Agent": UA}) as client:
        for page in range(1, max(1, max_pages) + 1):
            url = f"https://{ABB_HOSTNAME}/page/{page}/?s={q}"
            try:
                resp = client.get(url)
                resp.raise_for_status()
            except httpx.HTTPError as exc:
                if not results:
                    return [{"error": f"AudioBookBay request failed: {exc}"}]
                break
            posts = BeautifulSoup(resp.text, "html.parser").select(".post")
            if not posts:
                break
            for post in posts:
                a = post.select_one(".postTitle > h2 > a")
                if not a or not a.get("href"):
                    continue
                results.append(
                    {
                        "title": a.text.strip(),
                        "link": f"https://{ABB_HOSTNAME}{a['href']}",
                    }
                )
    return results or [{"info": "no results"}]


@mcp.tool()
def add_abb(link: str, title: str) -> str:
    """Send an AudioBookBay release (by detail-page link + title) to Transmission.

    `link` and `title` come from a search_abb result. The audiobookbay-automated
    app extracts the magnet and queues it; the import pipeline files it into
    Audiobookshelf once complete.
    """
    try:
        with httpx.Client(timeout=60) as client:
            r = client.post(f"{ABB_APP_URL}/send", json={"link": link, "title": title})
        body = r.json().get("message", r.text)
        return f"[{r.status_code}] {body}"
    except Exception as exc:  # noqa: BLE001
        return f"error: {exc}"


@mcp.tool()
def search_usenet(query: str, limit: int = 25) -> list[dict]:
    """Search Usenet indexers (e.g. NZBGeek) for audiobooks via Prowlarr.

    Searches the audiobook category and returns ONLY Usenet (NZB) releases —
    torrent-protocol results from the same category are dropped so every
    result is grab_usenet/SABnzbd-compatible. For torrents use search_abb.
    Requires Prowlarr to be reachable with an API key.
    """
    if not PROWLARR_API_KEY:
        return [{"error": "PROWLARR_API_KEY not configured"}]
    params = {
        "query": query,
        "categories": USENET_CATEGORIES,
        "type": "search",
        "limit": limit,
    }
    try:
        with httpx.Client(
            timeout=60, headers={"X-Api-Key": PROWLARR_API_KEY}
        ) as client:
            r = client.get(f"{PROWLARR_URL}/api/v1/search", params=params)
            r.raise_for_status()
            items = r.json()
    except Exception as exc:  # noqa: BLE001
        return [{"error": f"Prowlarr search failed: {exc}"}]
    out = []
    for it in items:
        if it.get("protocol") != "usenet":
            continue  # drop torrent results; use search_abb for those
        size = it.get("size") or 0
        out.append(
            {
                "title": it.get("title"),
                "indexer": it.get("indexer"),
                "size_mb": round(size / (1024 * 1024), 1) if size else None,
                "grabs": it.get("grabs"),
                "protocol": it.get("protocol"),
                "downloadUrl": it.get("downloadUrl")
                or it.get("magnetUrl")
                or it.get("guid"),
            }
        )
    return out or [{"info": "no results"}]


@mcp.tool()
def grab_usenet(download_url: str, name: str = "audiobook") -> str:
    """Send a Usenet release (downloadUrl from search_usenet) to SABnzbd.

    SABnzbd downloads the NZB; the import pipeline files it into Audiobookshelf.
    """
    if not SABNZBD_API_KEY:
        return "error: SABNZBD_API_KEY not configured"
    params = {
        "mode": "addurl",
        "name": download_url,
        "nzbname": name,
        "apikey": SABNZBD_API_KEY,
        "output": "json",
    }
    try:
        with httpx.Client(timeout=60) as client:
            r = client.get(f"{SABNZBD_URL}/api", params=params)
        return f"[{r.status_code}] {r.text}"
    except Exception as exc:  # noqa: BLE001
        return f"error: {exc}"


def _abs_library_id(client: httpx.Client) -> str | None:
    r = client.get(f"{ABS_URL}/api/libraries", headers=_abs_headers())
    r.raise_for_status()
    libs = r.json().get("libraries", [])
    for lib in libs:
        if lib.get("mediaType") == "book":
            return lib.get("id")
    return libs[0]["id"] if libs else None


@mcp.tool()
def search_library(query: str) -> list[dict]:
    """Search the Audiobookshelf library for already-owned audiobooks.

    Use this before acquiring to avoid duplicates.
    """
    try:
        with httpx.Client(timeout=30) as client:
            lib_id = _abs_library_id(client)
            if not lib_id:
                return [{"error": "no Audiobookshelf library found"}]
            r = client.get(
                f"{ABS_URL}/api/libraries/{lib_id}/search",
                params={"q": query},
                headers=_abs_headers(),
            )
            r.raise_for_status()
            data = r.json()
    except Exception as exc:  # noqa: BLE001
        return [{"error": f"Audiobookshelf search failed: {exc}"}]
    out = []
    for entry in data.get("book", []):
        media = entry.get("libraryItem", {}).get("media", {}).get("metadata", {})
        out.append(
            {
                "title": media.get("title"),
                "author": media.get("authorName") or media.get("authors"),
                "series": media.get("seriesName"),
            }
        )
    return out or [{"info": "not in library"}]


@mcp.tool()
def recent_library_items(limit: int = 10) -> list[dict]:
    """List the most recently added audiobooks in Audiobookshelf."""
    try:
        with httpx.Client(timeout=30) as client:
            lib_id = _abs_library_id(client)
            if not lib_id:
                return [{"error": "no Audiobookshelf library found"}]
            r = client.get(
                f"{ABS_URL}/api/libraries/{lib_id}/items",
                params={"sort": "addedAt", "desc": 1, "limit": limit},
                headers=_abs_headers(),
            )
            r.raise_for_status()
            data = r.json()
    except Exception as exc:  # noqa: BLE001
        return [{"error": f"Audiobookshelf request failed: {exc}"}]
    out = []
    for item in data.get("results", [])[:limit]:
        md = item.get("media", {}).get("metadata", {})
        out.append({"title": md.get("title"), "author": md.get("authorName")})
    return out or [{"info": "library empty"}]


def main():
    mcp.run()


if __name__ == "__main__":
    main()
