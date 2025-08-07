{
  pkgs,
  ...
}: {
  # Enhanced greetd display manager with tuigreet
  services.greetd = {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --greeting 'Welcome to P620 AMD Workstation'";
        user = "greeter";
      };
    };
  };

  # Install greetd-related packages
  environment.systemPackages = with pkgs; [
    tuigreet
  ];

  # Enhanced security and authentication configuration
  security = {
    # Unlock GNOME keyring on login
    pam.services.greetd = {
      enableGnomeKeyring = true;
    };

    # Polkit for privilege escalation
    polkit.enable = true;
  };

  # Session configuration for privilege escalation
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

  # AMD-specific environment variables
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
    WLR_NO_HARDWARE_CURSORS = "1"; # AMD cursor fix
  };

  # Console configuration
  console = {
    earlySetup = true; # Setup console early for faster boot
  };
}
