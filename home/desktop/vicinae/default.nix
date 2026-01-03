{ config
, lib
, pkgs
, vicinae-extensions
, ...
}:
with lib; let
  cfg = config.desktop.vicinae;
in
{
  options.desktop.vicinae = {
    enable = mkEnableOption {
      default = false;
      description = "Vicinae spatial file manager with grid layout and extensions";
    };
  };

  config = mkIf cfg.enable {
    # Configure vicinae service using the Home Manager module
    services.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
        environment = {
          USE_LAYER_SHELL = "1";
        };
      };
      settings = {
        close_on_focus_loss = true;
        consider_preedit = true;
        pop_to_root_on_close = true;
        favicon_service = "twenty";
        search_files_in_root = true;
        font = {
          normal = {
            size = 12;
            normal = "Maple Nerd Font";
          };
        };
        theme = {
          dark = {
            name = mkForce "gruvbox-dark";
            icon_theme = "default";
          };
        };
        launcher_window = {
          opacity = mkForce 0.98;
        };
      };
      # Configure extensions declaratively
      # Full list: https://github.com/vicinaehq/extensions/tree/main/extensions
      # Note: 'dbus' and 'systemd' are excluded from Nix packages
      extensions = with vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
        # Productivity
        agenda # Calendar and agenda viewer

        # Development
        nix # Nix package search and information
        vscode-recents # Recent VS Code projects

        # Bookmarks and browsing
        chromium-bookmarks # Chromium/Chrome bookmarks
        firefox # Firefox bookmarks

        # System management
        power-profile # Power profile switcher
        process-manager # Process management

        # Additional useful extensions
        bluetooth # Bluetooth device management
        wifi-commander # WiFi network management
        ssh # SSH connection manager
      ];
    };
  };
}
