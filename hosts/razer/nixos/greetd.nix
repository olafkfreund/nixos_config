{ config
, ...
}: {
  # NOTE: greetd display manager disabled - using COSMIC Greeter instead
  # COSMIC Greeter is enabled via features.desktop.cosmic.useCosmicGreeter = true
  # which provides proper lock/logout functionality for COSMIC Desktop
  #
  # If you need to fall back to tuigreet, disable cosmic-greeter first:
  # features.desktop.cosmic.useCosmicGreeter = false;
  # Then uncomment the greetd configuration below:
  #
  # services.greetd = {
  #   enable = true;
  #   settings = {
  #     terminal.vt = 1;
  #     default_session = {
  #       command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --greeting 'Welcome to Razer Gaming Laptop'";
  #       user = "greeter";
  #     };
  #   };
  # };

  # Security and authentication configuration
  security = {
    # Unlock GNOME keyring on login
    pam.services = {
      cosmic-greeter = {
        enableGnomeKeyring = true;
        # Enable fingerprint authentication if available
        fprintAuth = config.services.fprintd.enable;
      };
    };

    # Polkit for privilege escalation
    polkit.enable = true;
  };

  # NVIDIA and Intel iGPU specific environment variables
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1"; # NVIDIA compatibility
    # Intel iGPU + NVIDIA optimization
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_DRM_NO_ATOMIC = "1"; # Prevent some NVIDIA issues
  };

  # Console configuration
  console = {
    earlySetup = true; # Setup console early for faster boot
    # keyMap definition removed to avoid conflict with i18n.nix
  };
}
