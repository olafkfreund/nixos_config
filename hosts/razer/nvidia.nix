{config, lib, pkgs, ...}:
let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in
{
#Nvidia
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;
  nvidiaPersistenced = true;
  open = false;
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};

# boot.kernelParams = [ "module_blacklist=i915" ];

hardware.nvidia.prime = {
  sync.enable = true;
  offload.enable = false; 
  intelBusId = "PCI:0:2:0";
  nvidiaBusId = "PCI:1:0:0";
  };

hardware.opengl = { 
   enable = true; 
   driSupport = true; 
   driSupport32Bit = true;
   extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        vaapiVdpau
        libvdpau-va-gl
        vulkan-validation-layers
      ]; 
}; 

environment = {
    systemPackages = with pkgs; [
      nvidia-offload
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
