{
  config,
  pkgs,
  ...
}: let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in {
  #Nvidia
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    nvidiaPersistenced = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # boot.kernelParams = [ "module_blacklist=i915" ];

  hardware.nvidia.prime = {
    sync.enable = false;
    offload.enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
     extraPackages = with pkgs; [
       intel-media-driver # LIBVA_DRIVER_NAME=iHD
       vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
       vaapiVdpau
       libvdpau-va-gl
       # vulkan-validation-layers
     ];
  };

  environment = {
    systemPackages = with pkgs; [
      nvidia-vaapi-driver
       libva
       libva-utils
       glxinfo
       clinfo
       virtualglLib
       vulkan-loader
       vulkan-tools
    ];
  };
}
