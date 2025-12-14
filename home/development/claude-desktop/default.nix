{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.development;
in
{
  imports = [
    ./mcp-config.nix # Claude Desktop MCP server configuration
  ];

  # Claude Desktop Application
  # Provides a locally-built version of Anthropic's Claude Desktop GUI application
  # Only enabled when development productivity features are enabled

  config = mkIf (cfg.enable && cfg.productivity) {
    # Install the Claude Desktop package from our custom packages
    home.packages = [ pkgs.customPkgs.claude-desktop ];

    # The desktop entry is already provided by the package itself
    # No need for manual xdg.desktopEntries configuration
  };
}
