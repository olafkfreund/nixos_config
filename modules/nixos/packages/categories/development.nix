# Development Packages
# Development tools and programming languages
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.development;
  # Import existing development package sets
  packageSets = import ../../packages/sets.nix { inherit pkgs lib; };
in
{
  options.packages.development = {
    enable = lib.mkEnableOption "Development packages";

    languages = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Language-specific development tools";
    };

    editors = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Development editors and IDEs";
    };

    tools = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Development utility tools";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      # Core development tools (always included, headless-compatible)
      packageSets.development.common

      # Language-specific packages (headless-compatible)
      ++ lib.optionals (cfg.languages.python or false) packageSets.development.python
      ++ lib.optionals (cfg.languages.nodejs or false) packageSets.development.nodejs
      ++ lib.optionals (cfg.languages.rust or false) packageSets.development.rust
      ++ lib.optionals (cfg.languages.go or false) packageSets.development.go
      ++ lib.optionals (cfg.languages.lua or false) packageSets.development.lua
      ++ lib.optionals (cfg.languages.nix or false) packageSets.development.nix

      # Editors (mix of headless and GUI)
      ++ lib.optionals (cfg.editors.neovim or false) [ neovim ]
      # GUI editors only if desktop is enabled
      ++ lib.optionals ((cfg.editors.vscode or false) && (config.packages.desktop.enable or false)) [ code-cursor ]

      # Development tools (mostly headless-compatible)
      ++ lib.optionals (cfg.tools.container or false) [ docker-compose dive ]
      ++ lib.optionals (cfg.tools.database or false) [ postgresql mysql-client ]
      ++ lib.optionals (cfg.tools.network or false) [ postman-cli httpie ];
  };
}
