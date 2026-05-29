# arr-suite-mcp — shaktech786/arr-suite-mcp-server
#
# MCP server exposing Plex + the *arr suite (Sonarr/Radarr/Prowlarr/Bazarr/
# Overseerr) to AI clients. Python, stdio-only transport. To run it as a
# network daemon on P510 it is wrapped by mcp-proxy (stdio→SSE) in
# modules/services/arr-suite-mcp.nix.
#
# Pinned to a commit (no upstream release tags); version tracks pyproject.
{ lib
, python3Packages
, fetchFromGitHub
}:

python3Packages.buildPythonApplication rec {
  pname = "arr-suite-mcp";
  version = "1.0.0-unstable-2025-11-08";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "shaktech786";
    repo = "arr-suite-mcp-server";
    rev = "96665c1074d55b1bfc19eedbc780f4ab512f420c";
    hash = "sha256-ifGXU5MJxa22El7hrmIkaWnqonLgBF36ssKMTlXrRL0=";
  };

  # Upstream's pyproject only lists the top-level package, so setuptools omits
  # the clients/routers/utils subpackages (ModuleNotFoundError at runtime).
  #
  # ProwlarrClient also forgets to override `_api_version`, so it inherits "v3"
  # from BaseArrClient and every request 404s (Prowlarr only exposes /api/v1).
  # Patch mirrors overseerr.py's existing override idiom.
  #
  # OverseerrClient inherits BaseArrClient.get_system_status() which hits
  # /api/v1/system/status, but Overseerr exposes the equivalent at /api/v1/status
  # (already implemented as get_status). Override to delegate so arr_get_system_status
  # stops reporting Overseerr as offline.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'packages = ["arr_suite_mcp"]' \
        'packages = ["arr_suite_mcp", "arr_suite_mcp.clients", "arr_suite_mcp.routers", "arr_suite_mcp.utils"]'

    substituteInPlace arr_suite_mcp/clients/prowlarr.py \
      --replace-fail \
        '    """Client for interacting with Prowlarr API."""' \
        '    """Client for interacting with Prowlarr API."""

        def __init__(self, base_url: str, api_key: str, timeout: int = 30, max_retries: int = 3):
            """Initialize Prowlarr client (uses v1 API)."""
            super().__init__(base_url, api_key, timeout, max_retries)
            self._api_version = "v1"  # Prowlarr uses v1'

    substituteInPlace arr_suite_mcp/clients/overseerr.py \
      --replace-fail \
        '    async def get_status(self) -> dict[str, Any]:' \
        '    async def get_system_status(self) -> dict[str, Any]:
            """Overseerr exposes status at /status, not /system/status."""
            return await self.get("status")

        async def get_status(self) -> dict[str, Any]:'
  '';

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    mcp
    httpx
    pydantic
    pydantic-settings
    python-dotenv
  ];

  # Test suite needs a live *arr stack / network; skip.
  doCheck = false;
  pythonImportsCheck = [ "arr_suite_mcp" "arr_suite_mcp.clients" "arr_suite_mcp.server" ];

  meta = {
    description = "MCP server for Plex and the *arr suite (Sonarr, Radarr, Prowlarr, Bazarr, Overseerr)";
    homepage = "https://github.com/shaktech786/arr-suite-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "arr-suite-mcp";
    platforms = lib.platforms.linux;
  };
}
