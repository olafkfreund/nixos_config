{
  config,
  pkgs,
  ...
}: {
  services.greetd = {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --greeting 'Welcome to Razer Gaming Laptop'";
        user = "greeter";
      };
    };
  };

  # Install greetd-related packages
  # greetd packages moved to main configuration.nix for consolidation

  # Security and authentication configuration
  security = {
    # Unlock GNOME keyring on login
    pam.services = {
      greetd = {
        enableGnomeKeyring = true;
        # Enable fingerprint authentication if available
        fprintAuth = config.services.fprintd.enable;
      };
    };

    # Polkit for privilege escalation
    polkit.enable = true;
  };

  # Session configuration
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = ["graphical-session.target"];
    wants = ["graphical-session.target"];
    after = ["graphical-session.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
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
