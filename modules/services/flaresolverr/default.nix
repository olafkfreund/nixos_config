# FlareSolverr Configuration Module
# A proxy server to bypass Cloudflare protection for web scraping applications
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.services.flaresolverr;
in
{
  options.services.flaresolverr = {
    enable = mkEnableOption "FlareSolverr proxy server";

    package = mkOption {
      type = types.package;
      default = pkgs.flaresolverr;
      defaultText = literalExpression "pkgs.flaresolverr";
      description = "The FlareSolverr package to use";
    };

    port = mkOption {
      type = types.port;
      default = 8191;
      description = "Port on which FlareSolverr will listen";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host address to bind to";
    };

    logLevel = mkOption {
      type = types.enum [ "debug" "info" "warning" "error" ];
      default = "info";
      description = "Log level for FlareSolverr";
    };

    logHtml = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to log HTML content";
    };

    captchaSolver = mkOption {
      type = types.enum [ "none" "hcaptcha-solver" "harvester" ];
      default = "none";
      description = "CAPTCHA solver to use";
    };

    testUrl = mkOption {
      type = types.str;
      default = "https://www.google.com";
      description = "URL to test browser functionality";
    };

    sessionTtl = mkOption {
      type = types.int;
      default = 600000;
      description = "Session time-to-live in milliseconds";
    };

    headless = mkOption {
      type = types.bool;
      default = true;
      description = "Run browser in headless mode";
    };

    browserTimeout = mkOption {
      type = types.int;
      default = 40000;
      description = "Browser timeout in milliseconds";
    };

    user = mkOption {
      type = types.str;
      default = "flaresolverr";
      description = "User to run FlareSolverr as";
    };

    group = mkOption {
      type = types.str;
      default = "flaresolverr";
      description = "Group to run FlareSolverr as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/flaresolverr";
      description = "Data directory for FlareSolverr";
    };

    extraEnvironment = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra environment variables for FlareSolverr";
      example = {
        PROMETHEUS_ENABLED = "true";
        PROMETHEUS_PORT = "8192";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for FlareSolverr";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      description = "FlareSolverr daemon user";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0755 ${cfg.user} ${cfg.group} - -"
    ];

    # FlareSolverr service
    systemd.services.flaresolverr = {
      description = "FlareSolverr proxy server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/flaresolverr";
        Restart = "always";
        RestartSec = 10;

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
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

      environment =
        {
          HOST = cfg.host;
          PORT = toString cfg.port;
          LOG_LEVEL = cfg.logLevel;
          LOG_HTML =
            if cfg.logHtml
            then "true"
            else "false";
          CAPTCHA_SOLVER = cfg.captchaSolver;
          TEST_URL = cfg.testUrl;
          SESSION_TTL = toString cfg.sessionTtl;
          HEADLESS =
            if cfg.headless
            then "true"
            else "false";
          BROWSER_TIMEOUT = toString cfg.browserTimeout;

          # Chrome/Chromium settings for headless operation
          DISPLAY = ":99";
          CHROME_ARGS = "--no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222";
        }
        // cfg.extraEnvironment;
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # Ensure required packages are available
    environment.systemPackages = with pkgs; [
      cfg.package
      chromium # Required for browser automation
    ];

    # Add monitoring integration if prometheus is enabled
    services.prometheus.exporters = mkIf (cfg.extraEnvironment.PROMETHEUS_ENABLED or false == "true") {
      flaresolverr = {
        enable = true;
        port = toInt (cfg.extraEnvironment.PROMETHEUS_PORT or "8192");
        listenAddress = cfg.host;
      };
    };
  };
}
