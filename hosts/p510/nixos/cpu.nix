{ lib, pkgs, ... }: {
  # CPU frequency scaling. Deliberately NOT "performance" any more.
  #
  # p510 hard-power-cut a fourth time on 2026-09-01 at 22:26. The GPU was not
  # the cause: its 130W cap had been in force for 6.5 hours. What the journal
  # shows in the final 30 seconds is Plex going from 7 to 12 concurrent
  # streams, exceeding the 3070 Ti's ~3-session NVENC limit, and falling back
  # to SOFTWARE x264 -- five transcoder processes spawned between 22:26:00 and
  # 22:26:02, each loading liblibx264_encoder.so. On 20 Broadwell-EP cores
  # held at maximum by the "performance" governor, that is the power spike
  # that tripped a 490W supply also feeding a GPU and three spinning disks.
  #
  # intel_pstate in active mode offers only "performance" and "powersave", and
  # "powersave" here is the DYNAMIC governor (the intel_pstate equivalent of
  # schedutil), not a fixed-low one. For a box that idles most of the day and
  # transcodes in bursts, "performance" bought nothing and cost headroom:
  # measured 2693MHz at idle before, 1200MHz after.
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";
  };

  # Hard ceiling on the P-state, which the governor alone does not give. 70%
  # caps sustained turbo around 2.5GHz -- still above the 2.2GHz base, so
  # transcoding is unaffected, while removing the top of the power curve where
  # a Xeon draws far past its 135W TDP. Written via tmpfiles because
  # intel_pstate exposes this only through sysfs and it does not survive a
  # reboot on its own.
  systemd.tmpfiles.rules = [
    "w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 70"
  ];

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
