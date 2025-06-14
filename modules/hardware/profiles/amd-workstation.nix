{
  config,
  lib,
  pkgs,
  ...
}: {
  # AMD Workstation Hardware Profile Configuration
  config = {
    # Enable AMD GPU drivers
    hardware.opengl = {
      enable = true;
      # driSupport is deprecated and removed
      extraPackages = with pkgs; [
        amdvlk
        rocm-opencl-icd
        rocm-opencl-runtime
      ];
      extraPackages32 = with pkgs; [
        driversi686Linux.amdvlk
      ];
    };

    # AMD CPU optimizations
    hardware.cpu.amd.updateMicrocode = true;

    # Enable ROCm for GPU compute
    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];

    # AMD-specific kernel modules
    boot.initrd.kernelModules = ["amdgpu"];

    # GPU temperature and fan control
    environment.systemPackages = with pkgs; [
      lm_sensors
      fancontrol
      radeontop
    ];

    # Power management
    powerManagement.cpuFreqGovernor = "performance";
  };
}
