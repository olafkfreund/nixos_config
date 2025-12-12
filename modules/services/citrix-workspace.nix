{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.citrix-workspace;
in
{
  options.services.citrix-workspace = {
    enable = mkEnableOption "Citrix Workspace";

    package = mkOption {
      type = types.package;
      default = pkgs.citrix_workspace;
      description = "Citrix Workspace package to use";
    };

    acceptLicense = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Accept the Citrix Workspace End User License Agreement.

        WARNING: By setting this to true, you accept the Citrix EULA.
        You must manually download the tarball from Citrix if required.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Allow broken and insecure packages for Citrix Workspace
    nixpkgs.config = {
      allowUnfree = true;
      allowBroken = true;
      permittedInsecurePackages = [
        "libsoup-2.74.3"
        "webkitgtk-2.42.4"
      ];
    };

    # Install Citrix Workspace
    environment.systemPackages = [ cfg.package ];

    # Enable required system services
    services.dbus.enable = true;
    services.udisks2.enable = true;

    # Required for Citrix ICA client
    environment.etc = {
      "ica_section_userexperience".text = ''
        [WFClient]
        Version=2
      '';
    };

    # Add Citrix certificates if needed
    security.pki.certificateFiles = mkIf cfg.acceptLicense [
      # Add custom Citrix certificates here if required
    ];

    # Firewall rules for Citrix
    networking.firewall = {
      allowedTCPPorts = [
        1494 # Citrix ICA
        2598 # Citrix Session Reliability
      ];
      allowedUDPPorts = [
        1604 # Citrix ICA Browser
        16500 # Citrix Receiver Audio
      ];
    };

    # Required libraries for Citrix Workspace
    environment.variables = {
      ICAROOT = "${cfg.package}/opt/Citrix/ICAClient";
    };

    # Desktop integration
    xdg.mime.enable = true;
    services.xserver.desktopManager.xterm.enable = mkDefault true;

    # Warnings and assertions
    warnings = optional (!cfg.acceptLicense) ''
      Citrix Workspace requires accepting the EULA.
      Set services.citrix-workspace.acceptLicense = true after reviewing the license.
    '';

    assertions = [
      {
        assertion = cfg.enable -> config.services.xserver.enable || config.programs.hyprland.enable;
        message = "Citrix Workspace requires a desktop environment (X11 or Wayland)";
      }
    ];
  };

  meta.maintainers = with lib.maintainers; [ ];
}
