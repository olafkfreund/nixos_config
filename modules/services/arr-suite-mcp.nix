# arr-suite MCP server — exposed as an HTTP/SSE daemon.
#
# arr-suite-mcp (shaktech786) is a stdio-only Python MCP server. To make it a
# tailnet-reachable daemon we wrap it with mcp-proxy (stdio→SSE):
#
#   mcp-proxy --host 0.0.0.0 --port <port> --pass-environment -- arr-suite-mcp
#
# Clients connect to the SSE endpoint:  http://<host>:<port>/sse
#
# The *arr API keys are supplied via an agenix EnvironmentFile
# (SONARR/RADARR/PROWLARR/OVERSEERR_API_KEY). Hosts/ports default to
# localhost:<standard> inside arr-suite, matching the services on p510.
# NZBGeek is reached transitively through Prowlarr's API.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.arr-suite-mcp;
in
{
  options.features.arr-suite-mcp = {
    enable = lib.mkEnableOption "arr-suite MCP server (SSE daemon via mcp-proxy)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3011;
      description = "Port the SSE bridge binds to (loopback always; tailnet + LAN via firewall).";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."arr-suite-mcp-env".path;
      defaultText = lib.literalExpression ''config.age.secrets."arr-suite-mcp-env".path'';
      description = "EnvironmentFile with the *arr API keys (KEY=VALUE per line).";
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to open the port on, in addition to tailscale0 and
        loopback. null exposes the daemon only via Tailscale. (No effect on
        hosts where the firewall is disabled.)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."arr-suite-mcp-env" = {
      file = ../../secrets/arr-suite-mcp-env.age;
      mode = "0400";
    };

    systemd.services.arr-suite-mcp = {
      description = "arr-suite MCP server (SSE bridge via mcp-proxy)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.mcp-proxy)
          "--host 0.0.0.0"
          "--port ${toString cfg.port}"
          "--pass-environment"
          "-- ${lib.getExe pkgs.customPkgs.arr-suite-mcp}"
        ];
        EnvironmentFile = cfg.environmentFile;

        DynamicUser = true;

        # Hardening (docs/PATTERNS.md security baseline)
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        ProtectHostname = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        # CPython + some C extensions map RWX; keep W^X off (matches litellm-router).
        MemoryDenyWriteExecute = false;
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];

        MemoryMax = "512M";
        TasksMax = 128;

        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    networking.firewall.interfaces = lib.mkMerge [
      { "tailscale0".allowedTCPPorts = [ cfg.port ]; }
      (lib.mkIf (cfg.listenLanInterface != null) {
        "${cfg.listenLanInterface}".allowedTCPPorts = [ cfg.port ];
      })
    ];
  };
}
