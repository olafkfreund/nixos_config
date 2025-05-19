{
  config,
  lib,
  pkgs,
  ...
}: {
  # Optimize for AMD Threadripper Pro in P620
  nixpkgs.localSystem = {
    system = "x86_64-linux";
    # Threadripper Pro uses Zen cores
    gcc.arch = "znver3"; # For Threadripper Pro 3000/5000 series
    gcc.tune = "znver3";
  };

  # CPU frequency scaling
  services.thermald.enable = true;
  powerManagement.cpuFreqGovernor = "performance";

  # CPU monitoring tools
  environment.systemPackages = with pkgs; [
    zenmonitor
    lm_sensors
    s-tui
    ryzen-smu
  ];

  # Enable AMD CPU specific optimizations
  hardware.cpu.amd.updateMicrocode = true;

  # Scheduler optimization for NUMA architecture
  boot.kernelParams = lib.mkAfter [
    "amd_pstate=active" # Use the AMD pstate driver
    "nohz_full=1-${toString (config.nix.settings.max-jobs - 1)}" # Tickless CPU except CPU 0
  ];

  # NUMA settings
  boot.kernel.sysctl = {
    "kernel.sched_autogroup_enabled" = 1;
    "kernel.sched_child_runs_first" = 0;
    "kernel.sched_migration_cost_ns" = 5000000;
    "kernel.numa_balancing_scan_delay_ms" = 1000;
  };
}
