# FlareSolverr Configuration for P510
# Manual installation without custom module
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Install FlareSolverr package
  environment.systemPackages = with pkgs; [
    flaresolverr
    chromium
    curl
    jq
  ];

  # Create FlareSolverr user
  users.users.flaresolverr = {
    isSystemUser = true;
    group = "flaresolverr";
    description = "FlareSolverr daemon user";
    home = "/var/lib/flaresolverr";
    createHome = true;
  };

  users.groups.flaresolverr = {};

  # Create data directory
  systemd.tmpfiles.rules = [
    "d '/var/lib/flaresolverr' 0755 flaresolverr flaresolverr - -"
  ];

  # FlareSolverr service
  systemd.services.flaresolverr = {
    description = "FlareSolverr proxy server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    
    serviceConfig = {
      Type = "simple";
      User = "flaresolverr";
      Group = "flaresolverr";
      WorkingDirectory = "/var/lib/flaresolverr";
      ExecStart = "${pkgs.flaresolverr}/bin/flaresolverr";
      Restart = "always";
      RestartSec = 10;
      
      # Security settings
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = ["/var/lib/flaresolverr"];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      LockPersonality = true;
      
      # Resource limits
      MemoryMax = "2G";
      CPUQuota = "200%";
      TasksMax = 1024;
    };

    environment = {
      HOST = "0.0.0.0";
      PORT = "8191";
      LOG_LEVEL = "info";
      LOG_HTML = "false";
      CAPTCHA_SOLVER = "none";
      TEST_URL = "https://www.google.com";
      SESSION_TTL = "600000";
      HEADLESS = "true";
      BROWSER_TIMEOUT = "40000";
      
      # Chrome/Chromium settings for headless operation
      DISPLAY = ":99";
      CHROME_ARGS = "--no-sandbox --disable-dev-shm-usage --disable-gpu --disable-extensions --disable-plugins --memory-pressure-off --max_old_space_size=4096";
      CHROME_NO_SANDBOX = "true";
    };
  };

  # Open firewall for FlareSolverr
  networking.firewall.allowedTCPPorts = [8191];
}