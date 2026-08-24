{ config
, pkgs
, ...
}: {
  # Graphics configuration (modern NixOS 24.11+)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Vulkan support
      # vulkan-validation-layers dropped: debug-only layer, broken build on
      # nixpkgs 1.4.350.0 (update_deps.py git-clones in the sandbox).
      vulkan-loader
      vulkan-tools

      # Video acceleration
      nvidia-vaapi-driver
      libva-vdpau-driver
      # libvdpau-va-gl removed - old unmaintained package with CMake compatibility issues
      # nvidia-vaapi-driver and libva-vdpau-driver provide complete video acceleration for NVIDIA
    ];
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA driver configuration for RTX 3070 Ti and RTX 3060
  hardware.nvidia = {
    # Modesetting is required for most Wayland compositors
    modesetting.enable = true;

    # Use proprietary drivers for better RTX 30 series stability
    open = false;

    # Power management settings (disabled for server stability)
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Nvidia settings GUI (disabled for headless server)
    nvidiaSettings = true;

    # Use stable production driver for RTX 30 series
    package = config.boot.kernelPackages.nvidiaPackages.production;

    # Enable persistence daemon for headless operation
    nvidiaPersistenced = true;
  };

  # Cap board power to fit the PSU.
  #
  # dmidecode -t 39 reports a 490W supply. Stock limits are 290W (3070 Ti) +
  # 170W (3060), which with a 135W Xeon E5-2698 v4 and ~100W of board, RAM,
  # five disks and fans comes to ~695W. p510 hard-power-cut three times on
  # 19/20 Aug 2026, every time while a GPU ramped from idle — twice during an
  # ollama model load, once mid-Plex-NVENC-transcode. No MCE, panic, OOM or
  # thermal event in any of them: the journal just stops mid-write.
  #
  # 130W + 110W brought the worst case to ~475W, under the rating. Transcoding
  # draws nowhere near the cap, so the practical cost is nil.
  #
  # The second card was physically removed on 2026-08-24, so only GPU 0 (the
  # RTX 3070 Ti at 03:00.0) is left. Its `-i 1` line stayed behind and failed
  # every boot with "No devices found", exiting 2 and leaving the unit failed
  # — which matters beyond tidiness, because one permanently-failed unit makes
  # every subsequent switch return exit 4 and can roll the deploy back.
  #
  # 130W is deliberately left as-is. The card's stock limit is 290W and the
  # PSU now has ~110W more headroom, but the freezes above are why this cap
  # exists at all, so raising it is a separate decision backed by its own
  # testing rather than a side effect of pulling a card.
  #
  # This runs as root on purpose — setting a power limit needs CAP_SYS_ADMIN
  # and /dev/nvidiactl, so the usual DynamicUser/ProtectHome hardening cannot
  # apply. It executes one binary with fixed arguments and exits.
  systemd.services.nvidia-power-limit = {
    description = "Cap NVIDIA board power to fit p510's 490W PSU";
    after = [ "nvidia-persistenced.service" ];
    wants = [ "nvidia-persistenced.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Persistence mode keeps the limit across client detach; -pl is not
      # sticky across a driver reload, hence re-applying at every boot.
      ExecStart = [
        "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -i 0 -pl 130"
      ];
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  # Kernel configuration for NVIDIA
  boot = {
    # Kernel parameters for proper NVIDIA functionality
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for proper modesetting
    ];

    # Load NVIDIA kernel modules at boot (not in initrd)
    kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    # Blacklist conflicting drivers
    blacklistedKernelModules = [ "nouveau" ];

    # Let hardware.nvidia module handle extraModulePackages automatically
  };

  # Docker NVIDIA support
  hardware.nvidia-container-toolkit.enable = true;

  # Create proper device nodes for NVIDIA
  services.udev.extraRules = ''
    KERNEL=="nvidia_uvm", GROUP="video", MODE="0664"
    KERNEL=="nvidia*", GROUP="video", MODE="0664"
  '';

  environment.systemPackages = with pkgs; [
    # NVIDIA monitoring
    nvtopPackages.nvidia # NVIDIA system monitor
    libva
    libva-utils

    # CUDA tools for development and debugging
    cudaPackages.cuda_nvcc
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];
}
