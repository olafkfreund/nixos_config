# audiobook-mcp — audiobook acquisition + library MCP server, as an SSE daemon.
#
# audiobook-mcp (pkgs.customPkgs.audiobook-mcp) is a stdio FastMCP server. To
# make it tailnet-reachable we wrap it with mcp-proxy (stdio→SSE):
#
#   mcp-proxy --host 0.0.0.0 --port <port> --pass-environment -- audiobook-mcp
#
# Clients connect to the SSE endpoint:  http://<host>:<port>/sse
#
# Backend URLs default to the local services on p510 and are passed as plain
# env; the API keys (PROWLARR/SABNZBD/ABS) come from an agenix EnvironmentFile
# read by systemd as root before dropping to the DynamicUser.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.audiobook-mcp;
in
{
  options.features.audiobook-mcp = {
    enable = lib.mkEnableOption "audiobook MCP server (SSE daemon via mcp-proxy)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3012;
      description = "Port the SSE bridge binds to (loopback always; tailnet + LAN via firewall).";
    };

    abbAppUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:5078";
      description = "audiobookbay-automated base URL (used to add ABB releases).";
    };

    prowlarrUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:9696";
      description = "Prowlarr base URL (Usenet/torrent indexer search).";
    };

    sabnzbdUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080";
      description = "SABnzbd base URL (Usenet grabs).";
    };

    audiobookshelfUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:13378";
      description = "Audiobookshelf base URL (library lookups).";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."audiobook-mcp-env".path;
      defaultText = lib.literalExpression ''config.age.secrets."audiobook-mcp-env".path'';
      description = "EnvironmentFile with backend API keys (PROWLARR/SABNZBD/ABS).";
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to open the port on, in addition to tailscale0 and
        loopback. null exposes the daemon only via Tailscale.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."audiobook-mcp-env" = {
      file = ../../secrets/audiobook-mcp-env.age;
      mode = "0400";
    };

    systemd.services.audiobook-mcp = {
      description = "audiobook MCP server (SSE bridge via mcp-proxy)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Restart when the encrypted env (API keys) changes, so rotating a key
      # and redeploying actually reloads it (EnvironmentFile alone won't).
      restartTriggers = [ config.age.secrets."audiobook-mcp-env".file ];

      environment = {
        ABB_APP_URL = cfg.abbAppUrl;
        PROWLARR_URL = cfg.prowlarrUrl;
        SABNZBD_URL = cfg.sabnzbdUrl;
        ABS_URL = cfg.audiobookshelfUrl;
      };

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.mcp-proxy)
          "--host 0.0.0.0"
          "--port ${toString cfg.port}"
          "--pass-environment"
          "-- ${lib.getExe pkgs.customPkgs.audiobook-mcp}"
        ];
        EnvironmentFile = cfg.environmentFile;

        DynamicUser = true;

        # Hardening (docs/PATTERNS.md security baseline; mirrors arr-suite-mcp).
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
