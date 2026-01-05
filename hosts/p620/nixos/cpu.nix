{ lib
, pkgs
, ...
}: {
  # CPU frequency scaling
  powerManagement.cpuFreqGovernor = "performance";

  # CPU monitoring tools
  environment.systemPackages = with pkgs; [
    # Temporarily disabled - upstream compilation error with start_gui function signature
    # zenmonitor
    lm_sensors
    s-tui
  ];

  # Enable AMD CPU specific optimizations
  hardware.cpu.amd.updateMicrocode = true;

  # Scheduler optimization for NUMA architecture
  # NOTE: CPU isolation and nohz_full disabled due to desktop performance issues
  # These settings are better suited for dedicated server/RT workloads
  # Re-enable only if you have specific real-time requirements
  boot.kernelParams = lib.mkAfter [
    "amd_pstate=active" # Use the AMD pstate driver
    # "nohz_full=1-127" # DISABLED: Causes scheduling delays on desktop
    "numa=on" # Explicitly enable NUMA support
    # "isolcpus=120-127" # DISABLED: Removes cores from desktop scheduler causing slowness
  ];

  # NUMA settings optimized for Threadripper PRO 3995WX
  # NOTE: BIOS change required - set "Memory Interleave" to "Channel" or enable NPS2/NPS4
  boot.kernel.sysctl = {
    "kernel.sched_autogroup_enabled" = 1;
    "kernel.sched_child_runs_first" = 0;
    # "kernel.sched_migration_cost_ns" = 5000000;

    # Enable NUMA balancing for better memory locality
    "kernel.numa_balancing" = 1;
    "kernel.numa_balancing_scan_delay_ms" = 1000;

    # Enable zone reclaim for NUMA optimization
    "vm.zone_reclaim_mode" = 1;
  };
}
