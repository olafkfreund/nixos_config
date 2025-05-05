{
  config,
  lib,
  username,
  pkgs,
  ...
}: {
  # greetd display manager with tuigreet frontend
  services.greetd = let
    # Define available sessions
    session_hypr = {
      command = "${lib.getExe config.programs.hyprland.package}";
      user = "${username}";
    };

    # Optional fallback session
    session_gnome = {
      command = "${pkgs.gnome.gnome-session}/bin/gnome-session";
      user = "${username}";
    };

    # Define the actual greeter command with tuigreet
    greetCommand = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd-shutdown ${pkgs.systemd}/bin/poweroff --cmd-reboot ${pkgs.systemd}/bin/reboot --remember --asterisks --greeting 'Welcome to NixOS' --width 60";
  in {
    enable = true;
    restart = true; # Auto-restart on failure
    vt = 2; # Use virtual terminal 2
    settings = {
      terminal = {
        vt = 1;
        switch = true; # Allow switching VTs
      };
      default_session = {
        command = greetCommand;
        user = "greeter";
      };
      initial_session = session_hypr;
    };
  };

  # Install greetd-related packages
  environment.systemPackages = with pkgs; [
    greetd.tuigreet
  ];

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

  # Console configuration
  console = {
    earlySetup = true; # Setup console early for faster boot
    keyMap = "gb"; # Set keyboard layout
  };
}
