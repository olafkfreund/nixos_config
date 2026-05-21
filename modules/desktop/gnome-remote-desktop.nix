{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkForce;
  cfg = config.features.gnome-remote-desktop;
in
{
  options.features.gnome-remote-desktop = {
    enable = mkEnableOption "GNOME Remote Desktop with optimized settings";
  };

  config = mkIf cfg.enable {
    # Services configuration
    services = {
      # Enable GNOME Remote Desktop backend (modern RDP implementation)
      gnome.gnome-remote-desktop.enable = true;

      # Completely disable xrdp to prevent port conflicts - GNOME Remote Desktop handles RDP
      xrdp.enable = lib.mkForce false;

      # Enable Avahi for service discovery
      avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          userServices = true;
        };
      };

      # Disable autologin for remote desktop security
      displayManager.autoLogin.enable = false;
      getty.autologinUser = lib.mkForce null;
    };

    # Systemd configuration
    systemd = {
      # Mask xrdp services to prevent any attempt to start them
      services = {
        xrdp.enable = lib.mkForce false;
        xrdp-sesman.enable = lib.mkForce false;

        # Ensure GNOME Remote Desktop service starts with the graphical target
        gnome-remote-desktop.wantedBy = [ "graphical.target" ];
      };

      # Auto-start the user-scope headless RDP listener on GNOME login.
      # Why: nixpkgs ships the unit but doesn't wire it into gnome-session.target.
      # Without this, the listener only starts if someone toggles RDP in GNOME
      # Settings, and any such enable creates a `~/.config/systemd/user/` symlink
      # to the current store path — which becomes a dangling "bad" unit after the
      # next package bump. Declaratively wiring via /etc/systemd/user/ avoids that
      # interop trap entirely. The headless daemon binds port 3389 directly.
      user.services.gnome-remote-desktop-headless.wantedBy = [ "gnome-session.target" ];

      # Disable systemd sleep/suspend on hosts that should always be reachable
      # (workstations, headless servers). Laptops keep suspend so lid-close
      # behaves; the dconf no-sleep policy in home/desktop/gnome/apps.nix
      # already prevents idle suspend during active RDP sessions.
      targets = mkIf (config.host.class or "workstation" != "laptop") {
        sleep.enable = mkForce false;
        suspend.enable = mkForce false;
      };
    };

    # Open firewall ports for GNOME Remote Desktop
    networking.firewall.allowedTCPPorts = [
      3389 # RDP port for GNOME Remote Desktop
      5900 # VNC port
    ];
  };
}
