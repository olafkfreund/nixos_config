{
  config,
  lib,
  pkgs,
  ...
}: {
  # CPU frequency scaling for Xeon workstation
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance"; # For workstation loads
  };

  # Workstation-oriented scheduler tuning
  boot.kernel.sysctl = {
    # Performance tuning
    "kernel.sched_min_granularity_ns" = 10000000; # 10ms
    "kernel.sched_wakeup_granularity_ns" = 15000000; # 15ms
    "kernel.sched_migration_cost_ns" = 5000000; # 5ms
    "kernel.sched_autogroup_enabled" = 0; # Disable autogroup for workstation loads
  };

  # Monitor tools specific for Xeon
  environment.systemPackages = with pkgs; [
    intel-gpu-tools # For integrated graphics if used
    lm_sensors # For temperature monitoring
    s-tui # Terminal UI for CPU monitoring
    i7z # Tool for monitoring Intel CPUs
    powertop # Power consumption monitoring
    # turbostat # Intel CPU power/frequency statistics
  ];

  # Thermal management for Xeon
  services.thermald.enable = true;
}
