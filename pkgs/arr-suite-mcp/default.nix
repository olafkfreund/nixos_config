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
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'packages = ["arr_suite_mcp"]' \
        'packages = ["arr_suite_mcp", "arr_suite_mcp.clients", "arr_suite_mcp.routers", "arr_suite_mcp.utils"]'
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
