{ pkgs, ... }: {
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
  #       command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --greeting 'Welcome to Samsung Laptop'";
  #       user = "greeter";
  #     };
  #   };
  # };

  # Install greetd-related packages (kept for potential fallback)
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
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
  # Console configuration
  console = {
    earlySetup = true; # Setup console early for faster boot
  };
}
