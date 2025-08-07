{ ...
}: {
  # Intel i7-10875H specific optimizations
  hardware.cpu.intel.updateMicrocode = true;

  # Power management for mobile CPU
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Use "performance" when on AC power
    powertop.enable = true;
  };

  # Intel-specific power management
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 80; # Limit max performance on battery

      # Optimize for 10th gen Intel
      INTEL_GPU_MIN_FREQ_ON_AC = 300;
      INTEL_GPU_MIN_FREQ_ON_BAT = 300;
      INTEL_GPU_MAX_FREQ_ON_AC = 1350;
      INTEL_GPU_MAX_FREQ_ON_BAT = 1100;
      INTEL_GPU_BOOST_FREQ_ON_AC = 1350;
      INTEL_GPU_BOOST_FREQ_ON_BAT = 900;
    };
  };
}
