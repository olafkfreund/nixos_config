{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.gnome-remote-desktop;
in
{
  options.features.gnome-remote-desktop = {
    enable = mkEnableOption "GNOME Remote Desktop with optimized settings";
  };

  config = mkIf cfg.enable {
    # Enable GNOME Remote Desktop backend (modern RDP implementation)
    services.gnome.gnome-remote-desktop.enable = true;

    # Disable xrdp to prevent port conflicts - GNOME Remote Desktop handles RDP
    services.xrdp.enable = lib.mkForce false;

    # Enable Avahi for service discovery
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
      };
    };

    # Ensure GNOME Remote Desktop service starts with the graphical target
    systemd.services.gnome-remote-desktop = {
      wantedBy = [ "graphical.target" ];
    };

    # Disable autologin for remote desktop security
    services.displayManager.autoLogin.enable = false;
    services.getty.autologinUser = lib.mkForce null;

    # Disable power management for remote desktop sessions
    systemd.targets.sleep.enable = mkForce false;
    systemd.targets.suspend.enable = mkForce false;

    # Open firewall ports for GNOME Remote Desktop
    networking.firewall.allowedTCPPorts = [
      3389 # RDP port for GNOME Remote Desktop
      5900 # VNC port
    ];
  };
}
