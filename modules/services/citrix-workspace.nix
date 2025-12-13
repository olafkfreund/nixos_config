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
        # Note: webkit2gtk-4.0 is now bundled directly in Citrix Workspace 2508.10+
        # to resolve Ubuntu 24.04+ compatibility issues. The permission below may
        # no longer be needed but is kept for compatibility with older nixpkgs versions.
        # See: https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/system-requirements.html
        "webkitgtk-2.42.4"
      ];
    };

    # Environment configuration
    environment = {
      # Install Citrix Workspace and required dependencies
      systemPackages = with pkgs; [
        cfg.package

        # Required system libraries per Citrix documentation
        gtk2
        gtk3
        libva
        json_c # JSON-C library for configuration parsing
        curl # Required for cloud authentication (7.68+ with OpenSSL)

        # Audio codecs (Speex and Vorbis)
        speex
        libvorbis

        # Multimedia support (GStreamer for multimedia redirection)
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-ugly
      ];

      # Required for Citrix ICA client
      etc = {
        "ica_section_userexperience".text = ''
          [WFClient]
          Version=2
        '';
      };

      # Required libraries for Citrix Workspace
      variables = {
        ICAROOT = "${cfg.package}/opt/Citrix/ICAClient";
      };
    };

    # System services
    services = {
      # Enable required system services
      dbus.enable = true;
      udisks2.enable = true;

      # Desktop integration
      xserver.desktopManager.xterm.enable = mkDefault true;
    };

    # USB support (udev is enabled by default in NixOS)
    services.udev.enable = true;

    # Hardware support
    hardware = {
      # OpenGL/Video acceleration (required for HDX)
      graphics.enable = true;
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

    # Desktop integration
    xdg.mime.enable = true;

    # Warnings and assertions
    warnings =
      optional (!cfg.acceptLicense) ''
        Citrix Workspace requires accepting the EULA.
        Set services.citrix-workspace.acceptLicense = true after reviewing the license.
      ''
      ++ optional (config.programs.hyprland.enable or false) ''
        WARNING: Citrix Workspace officially supports X11 only.
        Wayland (including Hyprland) is NOT officially supported and may have issues.
        Consider using XWayland or a pure X11 session for Citrix.
        See: https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/system-requirements.html
      ''
      ++ optional (config.services.displayManager.gdm.wayland or false) ''
        WARNING: GDM Wayland session detected.
        Citrix Workspace requires X11. Switch to X11 session or use XWayland.
      '';

    assertions = [
      {
        assertion = cfg.enable -> (config.services.xserver.enable || config.programs.hyprland.enable);
        message = "Citrix Workspace requires a desktop environment (X11 or XWayland)";
      }
      {
        assertion = cfg.enable -> cfg.acceptLicense;
        message = ''
          Citrix Workspace requires EULA acceptance.
          Set services.citrix-workspace.acceptLicense = true after reviewing:
          https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html
        '';
      }
    ];
  };

  meta.maintainers = with lib.maintainers; [ ];
}
