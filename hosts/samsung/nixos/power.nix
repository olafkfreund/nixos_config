{
  pkgs,
  ...
}: {
  # Thermal and power management services
  services = {
    # CPU temperature monitoring and management
    thermald.enable = true;

    # Battery status monitoring
    upower = {
      enable = true;
      # Enable percentage-based notifications
      percentageLow = 15;
      percentageCritical = 5;
      percentageAction = 3;
    };

    # Power profiles management
    power-profiles-daemon = {
      enable = false;
      # Set default profile (options: power-saver, balanced, performance)
      # The following line is commented out as the default is 'balanced'
      # extraConfig.defaults.default-profile = "balanced";
    };

    # Advanced CPU frequency management (disabled but configured)
    auto-cpufreq = {
      enable = false;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "auto";
          energy_performance_preference = "power";
          cpu_energy_performance_policy = "power";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
          energy_performance_preference = "performance";
          cpu_energy_performance_policy = "performance";
        };
      };
    };
  };

  # Power-related packages
  environment.systemPackages = with pkgs; [
    cpupower-gui # GUI for CPU frequency scaling
    powertop # Power consumption analyzer
    lm_sensors # Hardware monitoring
    s-tui # Terminal UI stress test and monitoring tool
    htop # Process viewer with power info
    acpi # Command line battery info
    # tlpui # GUI for TLP (if using TLP)
  ];

  # Kernel parameters for better power efficiency
  boot.kernelParams = [
    "mem_sleep_default=deep" # Prefer deep sleep modes
    "nvme.noacpi=1" # Avoid ACPI conflicts with NVMe
  ];

  # Set CPU governor on boot
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Can be "ondemand", "powersave", or "performance"
    powertop.enable = true; # Run powertop auto-tune on startup
  };

  # Fix systemd sleep targets
  systemd = {
    targets = {
      sleep.enable = true;
      suspend.enable = true;
      hibernate.enable = true;
      "hybrid-sleep".enable = true;
    };

    # Add sleep hooks to handle hardware properly during sleep/resume
    services.fix-suspend-issues = {
      description = "Fix issues when resuming from suspend";
      wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      script = ''
        # Reset USB devices if needed
        ${pkgs.usbutils}/bin/usb-devices > /dev/null

        # Reset audio if needed
        ${pkgs.pulseaudio}/bin/pactl suspend-sink @DEFAULT_SINK@ false

        # Reset network interfaces if needed
        ${pkgs.iproute2}/bin/ip link set dev wlan0 down || true
        ${pkgs.iproute2}/bin/ip link set dev wlan0 up || true
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
