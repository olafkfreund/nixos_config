_: {
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

      # i915 frequency bounds for the iGPU (UHD Graphics on Comet Lake).
      # Values must lie within the hardware-reported min and max from
      # /sys/class/drm/card*/gt_min_freq_mhz and gt_max_freq_mhz; on
      # kernel 7.0.3 these are 350 and 1200 respectively (verified live).
      # Pre-#464 the file had 300 and 1350, which TLP rejected as
      # "frequency invalid or out of range" on 7.0.x — the failure
      # cascaded to nixos-rebuild exiting with status 4.
      INTEL_GPU_MIN_FREQ_ON_AC = 350;
      INTEL_GPU_MIN_FREQ_ON_BAT = 350;
      INTEL_GPU_MAX_FREQ_ON_AC = 1200;
      INTEL_GPU_MAX_FREQ_ON_BAT = 1100;
      INTEL_GPU_BOOST_FREQ_ON_AC = 1200;
      INTEL_GPU_BOOST_FREQ_ON_BAT = 900;
    };
  };
}
