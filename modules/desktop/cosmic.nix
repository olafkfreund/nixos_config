{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.desktop.cosmic;
in {
  options.features.desktop.cosmic = {
    enable = mkEnableOption "COSMIC Desktop Environment";

    useCosmicGreeter = mkOption {
      type = types.bool;
      default = true;
      description = "Use COSMIC Greeter as the display manager";
    };

    defaultSession = mkOption {
      type = types.bool;
      default = false;
      description = "Set COSMIC as the default desktop session";
    };

    installAllApps = mkOption {
      type = types.bool;
      default = true;
      description = "Install all COSMIC applications and extensions";
    };
  };

  config = mkIf cfg.enable {
    # Enable COSMIC Desktop Environment
    services.desktopManager.cosmic.enable = true;

    # Use COSMIC Greeter as display manager
    services.displayManager.cosmic-greeter.enable = cfg.useCosmicGreeter;

    # Set as default session if requested
    services.displayManager.defaultSession = mkIf cfg.defaultSession "cosmic";

    # COSMIC applications and utilities
    environment.systemPackages = with pkgs;
      [
        # Essential applications (always installed)
        cosmic-edit # Text editor
        cosmic-files # File manager
        cosmic-term # Terminal emulator
        cosmic-settings # System settings

        #Applications for COSMIC core functionality
        quick-webapps # Web application integration
        tasks

        # Wayland utilities
        wl-clipboard
        wl-clipboard-x11

        # Screenshot and screen recording support
        grim
        slurp

        # Notifications
        libnotify
      ]
      ++ optionals cfg.installAllApps [
        # Productivity applications
        cosmic-tasks # Task/TODO manager
        cosmic-reader # PDF/document reader
        cosmic-store # Application store
        cosmic-player # Media player

        # System utilities
        cosmic-screenshot # Screenshot tool
        cosmic-randr # Display configuration

        # Extensions and tweaks
        cosmic-ext-calculator # Calculator application
        cosmic-ext-tweaks # Advanced tweaking tool
        cosmic-ext-ctl # Extension control tool

        # Visual assets
        cosmic-icons # COSMIC icon theme
        cosmic-wallpapers # Wallpaper collection

        # Development/Design tools
        cosmic-design-demo # Design system demo
      ];

    # XDG portal configuration for COSMIC
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-cosmic];
      config.cosmic.default = ["cosmic" "*"];
    };

    # Required system services
    security.polkit.enable = true;

    # Hardware acceleration
    hardware.graphics.enable = true;

    # Font configuration for better COSMIC experience
    fonts.packages = with pkgs; [
      fira
      fira-code
      fira-code-symbols
      font-awesome
    ];

    # COSMIC-specific environment variables
    environment.sessionVariables = {
      # Enable Wayland for compatible applications
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
    };
  };
}
