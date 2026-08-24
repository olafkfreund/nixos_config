{ config
, pkgs
, lib
, ...
}: {
  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      nvidiaPersistenced = false;
      open = true; # NVIDIA 590+ requires open kernel modules for Turing GPUs (RTX 2070 Super)
      nvidiaSettings = true;
      # beta (595.45.04) fails to build against kernel 7.1 — it includes
      # linux/of_gpio.h, removed in 7.x. latest (610.43.02) handles the removal.
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      prime = {
        sync.enable = true;
        offload.enable = false;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # Vulkan support
        # vulkan-validation-layers dropped: debug-only layer, broken build on
        # nixpkgs 1.4.350.0 (update_deps.py git-clones in the sandbox).
        vulkan-loader
        vulkan-tools

        # Video acceleration
        libva-vdpau-driver
        nvidia-vaapi-driver

        # Intel iGPU video decode (Optimus: the Intel chip drives the panel and
        # should do video, leaving the dGPU idle). Without this there is NO
        # Intel VA-API driver in the closure at all — /run/opengl-driver/lib/dri
        # had neither iHD nor i965 — so browsers and players fell back to
        # software decode and burned battery.
        #
        # Deliberately NOT paired with LIBVA_DRIVER_NAME=nvidia: forcing VA-API
        # at the dGPU on a hybrid laptop defeats exactly this. Leave the driver
        # unset so libva picks per-device.
        intel-media-driver

        # # CUDA support
        # cudaPackages.cudatoolkit
        # cudaPackages.cudnn
      ];
    };

    # Docker NVIDIA support
    nvidia-container-toolkit.enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      # nvidia-vaapi-driver
      libva
      libva-utils
      # nvtop
      # mesa-demos
      # clinfo
      # virtualglLib
      # vulkan-loader
      # vulkan-tools
    ];
  };
  # Kernel parameters for better NVIDIA performance and stability
  boot = {
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for Wayland
      "nvidia-drm.fbdev=1" # Fixes external-monitor flicker on niri: without a DRM
      # fbdev the NVIDIA driver drops the surface in the vblank callback on the
      # second dGPU-driven CRTC ("missing surface in vblank callback").
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Helps with suspend/resume
      "nvidia.NVreg_TemporaryFilePath=/tmp" # Fix for temp file issues
    ];

    # Early load NVIDIA modules
    initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  };

  # nvidia-container-toolkit CDI generator fails during switch when driver version
  # mismatches (old kernel module vs new userspace). It succeeds after reboot.
  # Wrap ExecStart so failure doesn't block deployment.
  systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStart = lib.mkForce
    (pkgs.writeShellScript "nvidia-cdi-generator-safe" ''
      ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
        --output=/var/run/cdi/nvidia.yaml --device-name-strategy=type-index 2>&1 || \
        echo "nvidia-cdi-generator: skipped (driver mismatch, will retry after reboot)"
    '');

  # Create proper device nodes for NVIDIA.
  # Note the 0664 + video group: some configs float around using MODE="0666",
  # which makes the GPU nodes world-writable. Group ownership is enough.
  services.udev.extraRules = ''
    KERNEL=="nvidia_uvm", GROUP="video", MODE="0664"
    KERNEL=="nvidia*", GROUP="video", MODE="0664"
  '';

  # The NVIDIA shader cache grows without bound and is pure derived data —
  # prune anything untouched for a week. tmpfiles rather than a bespoke
  # service+timer: the `e` type is documented to accept shell-style globs and
  # apply age-based cleanup, which is exactly this job. (`d` does NOT glob —
  # a common mistake.) Cleanup runs via systemd-tmpfiles-clean.timer.
  systemd.tmpfiles.rules = [
    "e /home/*/.cache/nvidia - - - 7d"
  ];

  # Remove global Firefox/Chromium configs to avoid conflicts
  # These will be handled in individual user configurations
}
