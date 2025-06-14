{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.desktop.hyprland;
in {
  options.custom.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop environment";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        general = {
          gaps_in = 5;
          gaps_out = 20;
          border_size = 2;
        };
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 8;
            passes = 1;
          };
        };
      };
      description = "Hyprland configuration settings";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional Hyprland configuration";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Monitor configurations";
      example = ["DP-1,2560x1440@165,0x0,1"];
    };

    keybinds = lib.mkOption {
      type = lib.types.attrs;
      default = {
        "SUPER, Return" = "exec, kitty";
        "SUPER, Q" = "killactive";
        "SUPER, M" = "exit";
        "SUPER, E" = "exec, thunar";
        "SUPER, V" = "togglefloating";
        "SUPER, R" = "exec, rofi -show drun";
        "SUPER, P" = "pseudo";
        "SUPER, J" = "togglesplit";
      };
      description = "Custom keybindings";
    };

    startup = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["waybar" "hyprpaper"];
      description = "Applications to start with Hyprland";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Hyprland
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Required packages
    environment.systemPackages = with pkgs; [
      # Core Hyprland ecosystem
      hyprland
      hyprpaper
      hypridle
      hyprlock

      # Wayland utilities
      wl-clipboard
      wf-recorder
      grim
      slurp
      swappy

      # Notification daemon
      dunst

      # Application launcher
      rofi-wayland

      # Status bar
      waybar

      # File manager
      thunar

      # Terminal
      kitty
    ];

    # XDG Portal for Hyprland
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-hyprland];
      config = {
        common = {
          default = ["hyprland" "gtk"];
        };
        hyprland = {
          default = ["hyprland" "gtk"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
          "org.freedesktop.impl.portal.Screencast" = ["hyprland"];
        };
      };
    };

    # Enable required services
    services.greetd = {
      enable = lib.mkDefault true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };

    # Enable polkit for authentication
    security.polkit.enable = true;

    # Fonts for Hyprland
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      (nerdfonts.override {fonts = ["FiraCode" "DroidSansMono"];})
    ];
  };
}
