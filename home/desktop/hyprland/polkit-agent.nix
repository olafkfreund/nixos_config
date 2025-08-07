{ pkgs, ... }: {
  systemd.user.services.polkit-kde-authentication-agent-1 = {
    Unit.Description = "polkit-kde-authentication-agent-1";

    Install = {
      WantedBy = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_kde}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
      Environment = [
        "DISPLAY=:0"
      ];
    };
  };

  # Adding GNOME Polkit Authentication Agent
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "polkit-gnome-authentication-agent-1";
      # Make sure it doesn't conflict with KDE agent
      Conflicts = [ "polkit-kde-authentication-agent-1.service" ];
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
      Environment = [
        "DISPLAY=:0"
      ];
    };
  };

  # Convenience option to choose which one to use
  home.extraConfig = {
    # Set to "kde" or "gnome" to select which agent to use
    polkitAgent = "gnome";
  };
}
