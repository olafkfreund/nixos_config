# plex-mcp-server — niavasha/plex-mcp-server
#
# Unified MCP server exposing Plex (and optionally Sonarr/Radarr/Trakt) to AI
# clients. TypeScript/Node, built hermetically with buildNpmPackage from the
# tagged release (NOT an npx wrapper) so it runs under a hardened systemd unit
# with no build- or run-time network access.
#
# Ships three bins (package.json `bin`): plex-mcp-server, plex-trakt-server,
# plex-arr-server. The systemd module (modules/services/plex-mcp.nix) runs the
# plex-mcp-server bin in HTTP transport mode.
{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs_22
}:

buildNpmPackage rec {
  pname = "plex-mcp-server";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "niavasha";
    repo = "plex-mcp-server";
    rev = "v${version}";
    hash = "sha256-stUvsAlsM2+vLFefHu6Tci5jz+CIDG7f+UM8+eSBw98=";
  };

  npmDepsHash = "sha256-Jix5dQG5b4NN7Umwjuthbz9/p1RTarbCMRAFIExFEAA=";

  nodejs = nodejs_22;

  # `npm run build` (tsc → build/) is the default npmBuildScript; dev deps
  # (typescript, tsx) are present for the build and pruned afterwards.

  meta = {
    description = "Unified MCP server for Plex, Sonarr, Radarr, and Trakt";
    homepage = "https://github.com/niavasha/plex-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "plex-mcp-server";
    platforms = lib.platforms.linux;
  };
}
