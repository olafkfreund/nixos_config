{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.hardware;
in {
  config = lib.mkIf (cfg.profile or null == "nvidia-gaming") {
    # NVIDIA drivers
    services.xserver.videoDrivers = ["nvidia"];

    hardware = {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      };

      nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = false; # Use proprietary drivers
        nvidiaSettings = true;

        # Enable CUDA
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
    };

    # Gaming optimizations
    programs.gamemode.enable = true;
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    # Gaming-specific packages
    environment.systemPackages = with pkgs; [
      nvidia-system-monitor-qt
      nvtop
      cudatoolkit
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
    ];

    # Performance tweaks
    boot.kernel.sysctl = {
      "vm.max_map_count" = 2147483642; # For some games
    };

    # Set hardware configuration
    custom.hardware = {
      gpu.vendor = "nvidia";
      gaming.optimizations = true;
      cuda.enable = true;
    };
  };
}
