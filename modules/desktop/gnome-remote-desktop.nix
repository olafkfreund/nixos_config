{ config, lib, ... }:
with lib;
let
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

      # Disable power management for remote desktop sessions
      targets = {
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
