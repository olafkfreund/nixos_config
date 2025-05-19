{
  config,
  lib,
  pkgs,
  ...
}: {
  # CPU frequency scaling
  powerManagement.cpuFreqGovernor = "performance";

  # CPU monitoring tools
  environment.systemPackages = with pkgs; [
    zenmonitor
    lm_sensors
    s-tui
  ];

  # Enable AMD CPU specific optimizations
  hardware.cpu.amd.updateMicrocode = true;

  # Scheduler optimization for NUMA architecture
  boot.kernelParams = lib.mkAfter [
    "amd_pstate=active" # Use the AMD pstate driver
    "nohz_full=1-127" # Tickless CPU except CPU 0
  ];

  # NUMA settings
  boot.kernel.sysctl = {
    "kernel.sched_autogroup_enabled" = 1;
    "kernel.sched_child_runs_first" = 0;
    # "kernel.sched_migration_cost_ns" = 5000000;
    "kernel.numa_balancing_scan_delay_ms" = 1000;
  };
}
