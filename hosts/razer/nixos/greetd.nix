{
  config,
  lib,
  username,
  pkgs,
  ...
}: {
  services.greetd = let
    session_hypr = {
      command = "${lib.getExe config.programs.hyprland.package}";
      user = "${username}";
    };
    session_sway = {
      command = "${lib.getExe config.programs.sway.package} --unsupported-gpu";
      user = "${username}";
    };
  in {
    enable = true;
    settings = {
      terminal.vt = 1;
      default_session = session_hypr;
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
    # keyMap definition removed to avoid conflict with i18n.nix
  };
}
