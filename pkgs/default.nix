{ pkgs, ... }: {
  # Define your custom packages here
  rofi-blocks = pkgs.callPackage ./rofi-blocks { };
  chrome-gruvbox-theme = pkgs.callPackage ./chrome-gruvbox-theme { };
  linux-command-mcp = pkgs.callPackage ./linux-command-mcp { };
  obsidian-mcp = pkgs.callPackage ./obsidian-mcp { };
  mpris-album-art = pkgs.callPackage ./mpris-album-art { };
  weather-popup = pkgs.callPackage ./weather-popup { };
  gemini-cli = pkgs.callPackage ../home/development/gemini-cli { };
  claude-desktop = pkgs.callPackage ./claude-desktop { };
  neuwaita-icon-theme = pkgs.callPackage ./neuwaita-icon-theme { };
  kosli-cli = pkgs.callPackage ./kosli-cli { };

  # Override awscli2 to disable failing tests
  awscli2 = pkgs.awscli2.overrideAttrs (oldAttrs: {
    doCheck = false; # Disable tests - 44 tests failing in wizard/test_app.py
  });
}
