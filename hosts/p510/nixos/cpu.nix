{ lib, pkgs, ... }: {
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

  # thermald cannot run on this box. The Xeon E5-2698 v4 (Broadwell-EP,
  # family 6 model 79) is a server part: thermald wants the Linux PowerCap
  # sysfs interface, which it does not expose, so every start logs
  #   Need Linux PowerCap sysfs / Unsupported cpu model or platform
  # and exits. A permanently-dead unit makes switch-to-configuration report
  # "units failed" -> exit 4 -> nh rolls the whole deploy back, so this must be
  # off rather than merely ignored. mkForce beats the Intel-CPU default in
  # modules/services/system/default.nix, which is true here but not sufficient.
  services.thermald.enable = lib.mkForce false;
}
