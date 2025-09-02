# Desktop GUI Packages
# GUI applications that require desktop environment
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.desktop;
  # Import existing desktop package sets
  packageSets = import ../../packages/sets.nix { inherit pkgs lib; };
in
{
  options.packages.desktop = {
    enable = lib.mkEnableOption "Desktop GUI packages";

    wayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Wayland-specific packages";
    };

    browsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Web browsers";
    };

    media = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Media applications";
    };

    productivity = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Productivity applications";
    };

    communication = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Communication applications";
    };
  };

  # Only enabled for GUI hosts - NO mkIf condition true!
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core desktop tools (always included when desktop enabled)
      xdg-utils
      desktop-file-utils
    ]
    # Wayland essentials
    ++ lib.optionals cfg.wayland packageSets.desktop.wayland

    # Browsers
    ++ lib.optionals (cfg.browsers.firefox or false) [ firefox ]
    ++ lib.optionals (cfg.browsers.chrome or false) [ google-chrome ]

    # Media applications (GUI-only)
    ++ lib.optionals (cfg.media.vlc or false) [ vlc ]
    ++ lib.optionals (cfg.media.spotify or false) [ spotify ]
    ++ lib.optionals (cfg.media.discord or false) [ discord ]
    ++ lib.optionals (cfg.media.obs or false) [ obs-studio ]
    ++ lib.optionals (cfg.media.gimp or false) [ gimp ]
    ++ lib.optionals (cfg.media.inkscape or false) [ inkscape ]

    # Productivity applications (GUI-only)
    ++ lib.optionals (cfg.productivity.obsidian or false) [ obsidian ]
    ++ lib.optionals (cfg.productivity.libreoffice or false) [ libreoffice ]
    ++ lib.optionals (cfg.productivity.thunderbird or false) [ thunderbird ]
    ++ lib.optionals (cfg.productivity.vscode or false) [ code-cursor ]

    # Communication applications (GUI-only)
    ++ lib.optionals (cfg.communication.slack or false) [ slack ]
    ++ lib.optionals (cfg.communication.zoom or false) [ zoom-us ]

    # Fonts (when desktop enabled)
    ++ packageSets.desktop.fonts;
  };
}
