{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.desktop;
in {
  options.custom.desktop = {
    enable = lib.mkEnableOption "desktop environment";

    session = lib.mkOption {
      type = lib.types.enum ["hyprland" "plasma" "gnome"];
      default = "hyprland";
      description = "Desktop session to use";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum ["greetd" "sddm" "gdm"];
      default = "greetd";
      description = "Display manager to use";
    };

    theme = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable custom theming";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "gruvbox-dark";
        description = "Theme name";
      };
    };

    audio = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable audio support";
      };

      lowLatency = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable low-latency audio";
      };
    };
  };

  imports = [
    ../modules/desktop/core.nix
    ../modules/desktop/hyprland.nix
    ../modules/desktop/plasma.nix
    ../modules/desktop/audio.nix
    ../modules/fonts
  ];

  config = lib.mkIf cfg.enable {
    # Enable base desktop services
    custom.base.enable = true;

    # XDG configuration
    xdg = {
      portal = {
        enable = true;
        extraPortals = with pkgs;
          [
            xdg-desktop-portal-gtk
          ]
          ++ lib.optionals (cfg.session == "hyprland") [
            xdg-desktop-portal-hyprland
          ]
          ++ lib.optionals (cfg.session == "plasma") [
            xdg-desktop-portal-kde
          ];
      };
      mime.enable = true;
    };

    # Audio configuration
    services.pipewire = lib.mkIf cfg.audio.enable {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = cfg.audio.lowLatency;
    };

    # Hardware support
    hardware = {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      };

      pulseaudio.enable = false; # Use PipeWire instead
    };

    # Enable session-specific configuration
    custom.desktop.hyprland.enable = cfg.session == "hyprland";
    custom.desktop.plasma.enable = cfg.session == "plasma";

    # Basic GUI applications
    environment.systemPackages = with pkgs; [
      # File managers
      thunar
      xfce.thunar-volman

      # Terminal emulators
      kitty
      alacritty

      # Basic utilities
      pavucontrol
      blueman
      networkmanagerapplet

      # Image viewers and editors
      feh
      imv
      gimp

      # Archive managers
      file-roller

      # Text editors
      gedit
    ];

    # Enable Bluetooth
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Enable printing
    services.printing = {
      enable = true;
      drivers = with pkgs; [hplip gutenprint];
    };

    # Enable location services
    services.geoclue2.enable = true;

    # Enable dbus
    services.dbus.enable = true;

    # Enable polkit
    security.polkit.enable = true;
  };
}
