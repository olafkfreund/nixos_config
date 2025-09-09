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
    # Enable GNOME Remote Desktop backend
    services.gnome.gnome-remote-desktop.enable = true;
    
    # Enable XRDP with GNOME session
    services.xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
      openFirewall = true;  # Automatically opens port 3389
    };
    
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
    systemd.targets.sleep.enable = false;
    systemd.targets.suspend.enable = false;

    # Open firewall ports for remote desktop (XRDP openFirewall already handles 3389)
    networking.firewall.allowedTCPPorts = [
      5900 # VNC port
    ];
  };
}