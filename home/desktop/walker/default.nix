{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
with lib; let
  cfg = config.desktop.walker;
in {
  options.desktop.walker = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Walker launcher";
    };

    runAsService = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run Walker as a background service for faster startup";
    };
  };

  config = mkIf cfg.enable {
    programs.walker = {
      enable = true;
      inherit (cfg) runAsService;
      # Configuration options for Walker
      config = {
        search.placeholder = "Search...";
        ui.fullscreen = true;
        list.height = 200;
        websearch.prefix = "?";
        switcher.prefix = "/";
      };
      # Default Gruvbox-styled configuration
      style = ''
        /* Gruvbox Dark Theme for Walker */
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 14px;
        }

        #window {
          background-color: #282828;
          color: #ebdbb2;
          border: 2px solid #504945;
          border-radius: 5px;
        }

        #input {
          color: #ebdbb2;
          background-color: #3c3836;
          border: 1px solid #504945;
          border-radius: 4px;
          margin: 8px;
          padding: 8px;
        }

        #input:focus {
          border-color: #fabd2f;
        }

        #list {
          background-color: #282828;
          border-top: 1px solid #504945;
        }

        #entry {
          padding: 8px;
        }

        #entry:selected {
          background-color: #504945;
        }

        #text {
          color: #ebdbb2;
        }

        #text:selected {
          color: #fbf1c7;
        }

        /* App icons section */
        #icon {
          margin-right: 8px;
        }

        /* Status indicators */
        #badge {
          margin-left: 8px;
          color: #83a598;
        }

        /* Color accents for different entry types */
        .file #text {
          color: #8ec07c;
        }

        .folder #text {
          color: #fabd2f;
        }

        .executable #text {
          color: #b8bb26;
        }

        .websearch #text {
          color: #83a598;
        }

        .calculator #text {
          color: #d3869b;
        }

        .switcher #text {
          color: #fe8019;
        }

        /* Scrollbar styling */
        scrollbar {
          background-color: #282828;
          border-radius: 4px;
          margin: 2px;
        }

        scrollbar slider {
          background-color: #504945;
          border-radius: 4px;
        }

        scrollbar slider:hover {
          background-color: #665c54;
        }
      '';
    };

    # Add auto-start for Hyprland if runAsService is enabled
    wayland.windowManager.hyprland.extraConfig = mkIf (cfg.runAsService && config.wayland.windowManager.hyprland.enable) ''
      exec-once=walker --gapplication-service
    '';

    # Add auto-start for Sway if runAsService is enabled
    wayland.windowManager.sway.config.startup = mkIf (cfg.runAsService && config.wayland.windowManager.sway.enable) [
      {command = "walker --gapplication-service";}
    ];
  };
}
