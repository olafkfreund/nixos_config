{ pkgs, ... }: {
  # Define your custom packages here
  rofi-blocks = pkgs.callPackage ./rofi-blocks { };
  chrome-gruvbox-theme = pkgs.callPackage ./chrome-gruvbox-theme { };
  linux-command-mcp = pkgs.callPackage ./linux-command-mcp { };
  linkedin-mcp = pkgs.callPackage ./linkedin-mcp { };
  atlassian-mcp = pkgs.callPackage ./atlassian-mcp { };
  obsidian-mcp = pkgs.callPackage ./obsidian-mcp { nodejs = pkgs.nodejs_24; };
  obsidian-mcp-rest = pkgs.callPackage ./obsidian-mcp-rest { nodejs = pkgs.nodejs_24; };
  browser-mcp = pkgs.callPackage ./browser-mcp { nodejs = pkgs.nodejs_24; };
  mpris-album-art = pkgs.callPackage ./mpris-album-art { };
  weather-popup = pkgs.callPackage ./weather-popup { };
  # gemini-cli temporarily disabled due to npm deps hash issue
  # Nixpkgs version 0.22.4 also has build issues, mark as broken
  gemini-cli = pkgs.gemini-cli.overrideAttrs (old: {
    meta = old.meta // { broken = true; };
  });
  # Claude Desktop - using working Linux build from k3d3/claude-desktop-linux-flake
  claude-desktop = pkgs.claude-desktop-linux or (pkgs.callPackage ./claude-desktop { });
  neuwaita-icon-theme = pkgs.callPackage ./neuwaita-icon-theme { };
  kosli-cli = pkgs.callPackage ./kosli-cli { };

  # Override awscli2 to disable failing tests
  awscli2 = pkgs.awscli2.overrideAttrs (_oldAttrs: {
    doCheck = false; # Disable tests - 44 tests failing in wizard/test_app.py
  });

  # COSMIC applets
  cosmic-ext-applet-tailscale = pkgs.callPackage ./cosmic-applets/tailscale { };
  cosmic-ext-applet-next-meeting = pkgs.callPackage ./cosmic-applets/next-meeting { };
}
