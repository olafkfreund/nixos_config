{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.applications.productivity;
in {
  options.custom.applications.productivity = {
    enable = lib.mkEnableOption "productivity applications";

    office = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable office suite applications";
      };

      suite = lib.mkOption {
        type = lib.types.enum ["libreoffice" "onlyoffice"];
        default = "libreoffice";
        description = "Office suite to use";
      };
    };

    noteApps = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable note-taking applications";
      };

      apps = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["obsidian" "logseq" "zettlr"]);
        default = ["obsidian"];
        description = "Note-taking apps to install";
      };
    };

    pdf = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable PDF applications";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [
        # Office suite
      ]
      ++ lib.optionals cfg.office.enable (
        if cfg.office.suite == "libreoffice"
        then [
          libreoffice-fresh
        ]
        else [
          onlyoffice-bin
        ]
      )
      ++ lib.optionals cfg.noteApps.enable (
        lib.flatten (map (
            app:
              if app == "obsidian"
              then [obsidian]
              else if app == "logseq"
              then [logseq]
              else if app == "zettlr"
              then [zettlr]
              else []
          )
          cfg.noteApps.apps)
      )
      ++ lib.optionals cfg.pdf.enable [
        # PDF tools
        evince
        okular
        xournalpp
      ]
      ++ [
        # General productivity
        calculator
        calendar
        gnome.gnome-clocks
      ];
  };
}
