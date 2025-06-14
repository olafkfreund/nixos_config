{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.hardware;
in {
  config = lib.mkIf (cfg.profile or null == "htpc-intel") {
    # Intel graphics with media acceleration
    hardware.opengl = {
      enable = true;
      driSupport = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        libvdpau-va-gl
        intel-compute-runtime
      ];
    };

    # CPU optimizations
    hardware.cpu.intel.updateMicrocode = true;

    # Media-focused services
    services.jellyfin.enable = lib.mkDefault false; # Can be enabled per host

    # HTPC-specific packages
    environment.systemPackages = with pkgs; [
      kodi
      vlc
      mpv
      jellyfin-media-player
      plex-media-player
    ];

    # Audio for HTPC
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    # Power efficiency
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };

    # Quiet operation
    boot.kernelParams = [
      "quiet"
      "splash"
    ];

    # Set hardware configuration
    custom.hardware = {
      cpu.vendor = "intel";
      gpu.vendor = "intel";
      media.acceleration = true;
      power.efficiency = true;
    };
  };
}
