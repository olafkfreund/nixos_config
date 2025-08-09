_: {
  # Increase resource limits for professional workloads
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "524288";
    }
    {
      domain = "*";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "*";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];

  # Optimize system responsiveness under high load
  boot.kernel.sysctl = {
    "kernel.sched_min_granularity_ns" = 10000000; # 10ms
    "kernel.sched_wakeup_granularity_ns" = 15000000; # 15ms
    "kernel.sched_migration_cost_ns" = 5000000; # 5ms
    "kernel.sched_latency_ns" = 60000000; # 60ms
  };
}
