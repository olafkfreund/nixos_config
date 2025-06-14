{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.desktop.core;
in {
  options.custom.desktop.core = {
    enable = lib.mkEnableOption "core desktop functionality";

    displayServer = lib.mkOption {
      type = lib.types.enum ["wayland" "x11"];
      default = "wayland";
      description = "Display server to use";
    };

    polkit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable polkit authentication agent";
      };
    };

    xdg = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable XDG desktop integration";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # XDG configuration
    xdg = lib.mkIf cfg.xdg.enable {
      portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
        ];
        config.common.default = ["gtk"];
      };
      mime.enable = true;
    };

    # Enable dbus
    services.dbus.enable = true;

    # Polkit for authentication
    security.polkit.enable = cfg.polkit.enable;

    # Font configuration
    fonts = {
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        liberation_ttf
        dejavu_fonts
        font-awesome
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = ["DejaVu Serif"];
          sansSerif = ["DejaVu Sans"];
          monospace = ["DejaVu Sans Mono"];
        };
      };
    };

    # Basic desktop packages
    environment.systemPackages = with pkgs; [
      # File management
      file
      unzip
      zip

      # System information
      neofetch
      lshw
      inxi

      # Process management
      htop
      btop
      killall
    ];

    # Enable location services for desktop features
    services.geoclue2.enable = true;

    # Enable GVFS for file manager functionality
    services.gvfs.enable = true;

    # Enable CUPS for printing
    services.printing.enable = true;

    # Enable UDisks for removable media
    services.udisks2.enable = true;
  };
}
