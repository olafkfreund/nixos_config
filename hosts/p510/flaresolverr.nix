# FlareSolverr Configuration for P510
# Uses built-in NixOS FlareSolverr service
{ pkgs, ... }: {
  # Enable the built-in NixOS FlareSolverr service
  services.flaresolverr = {
    enable = true;

    # Network configuration
    openFirewall = true; # Open port 8191 automatically

    # Service configuration
    package = pkgs.flaresolverr;
  };

  # Additional packages for debugging and monitoring
  environment.systemPackages = with pkgs; [
    curl
    jq
  ];

  # Optional: Custom service configuration overrides
  systemd.services.flaresolverr = {
    # Override environment variables for the built-in service
    environment = {
      HOST = "0.0.0.0"; # Bind to all interfaces
      PORT = "8191"; # Default port
      LOG_LEVEL = "info"; # Logging level
      LOG_HTML = "false"; # Don't log HTML content
      CAPTCHA_SOLVER = "none"; # Disable CAPTCHA solver
      TEST_URL = "https://www.google.com"; # Test URL
      SESSION_TTL = "600000"; # 10 minutes session timeout
      HEADLESS = "true"; # Run in headless mode
      BROWSER_TIMEOUT = "40000"; # 40 second browser timeout

      # Chrome optimization flags
      CHROME_ARGS = "--no-sandbox --disable-dev-shm-usage --disable-gpu --disable-extensions --disable-plugins --memory-pressure-off --max_old_space_size=4096";
      CHROME_NO_SANDBOX = "true";
      DISPLAY = ":99";
    };

    # Additional service configuration
    serviceConfig = {
      # Resource limits
      MemoryMax = "2G";
      CPUQuota = "200%";
      TasksMax = 1024;

      # Additional security hardening
      PrivateDevices = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelLogs = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictNamespaces = true;
      SystemCallArchitectures = "native";

      # Performance tuning for P510
      CPUSchedulingPolicy = 1; # SCHED_FIFO
      CPUSchedulingPriority = 10;
      Nice = -5;

      # I/O optimization
      IOSchedulingClass = 2;
      IOSchedulingPriority = 4;
    };

    # Ensure service starts after network
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
