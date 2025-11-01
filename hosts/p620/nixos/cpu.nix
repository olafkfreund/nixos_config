{ lib
, pkgs
, ...
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
    "numa=on" # Explicitly enable NUMA support
    "isolcpus=120-127" # Reserve last 8 cores for dedicated/real-time workloads
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
