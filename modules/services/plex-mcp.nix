# Plex MCP server — niavasha/plex-mcp-server run as an SSE daemon.
#
# Exposes the local Plex Media Server (and optionally Sonarr/Radarr) to AI
# clients over the Model Context Protocol. Clients connect to:
#   http://<host>:<port>/sse     (SSE transport)
#
# plex-mcp-server's native --transport http uses a single shared session for
# the process lifetime, which wedges when a client reconnects. We instead run
# it in stdio mode behind mcp-proxy, which spawns a fresh stdio child per
# session — robust across reconnects, and consistent with features.arr-suite-mcp.
#
# Network: binds 0.0.0.0:<port> but the firewall opens it ONLY on tailscale0
# (+ optional LAN interface) — never globally reachable. Loopback always works.
#
# Secret: the Plex auth token is loaded at runtime from agenix via
# LoadCredential (never in the Nix store), exported into the wrapper, and
# passed to the stdio child by mcp-proxy --pass-environment. PLEX_URL is
# non-secret and set as a plain unit Environment value.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.plex-mcp;
in
{
  options.features.plex-mcp = {
    enable = lib.mkEnableOption "Plex MCP server (HTTP transport daemon)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3010;
      description = "Port the MCP server binds to (loopback always; tailnet + LAN via firewall).";
    };

    plexUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:32400";
      description = "URL of the Plex Media Server the MCP server talks to.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."plex-token".path;
      defaultText = lib.literalExpression ''config.age.secrets."plex-token".path'';
      description = ''
        Path to a file containing ONLY the Plex auth token. Loaded into the
        unit at runtime via LoadCredential. Defaults to the agenix secret
        declared by this module.
      '';
    };

    enableMutativeOps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Plex write/mutative tools (PLEX_ENABLE_MUTATIVE_OPS). Disabled
        by default for safety — read-only tools only.
      '';
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to open the port on, in addition to tailscale0 and
        loopback. Set to the host's actual LAN NIC (confirm with `ip link`).
        null exposes the server only via Tailscale.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."plex-token" = {
      file = ../../secrets/plex-token.age;
      mode = "0400";
    };

    systemd.services.plex-mcp = {
      description = "Plex MCP server (SSE bridge via mcp-proxy)";
      after = [ "network-online.target" "plex.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        PLEX_URL = cfg.plexUrl;
      } // lib.optionalAttrs cfg.enableMutativeOps {
        PLEX_ENABLE_MUTATIVE_OPS = "true";
      };

      serviceConfig = {
        # mcp-proxy spawns a fresh plex-mcp-server (stdio) per session and
        # exposes it over SSE. PLEX_TOKEN/PLEX_URL reach the child via
        # --pass-environment.
        ExecStart = pkgs.writeShellScript "plex-mcp-start" ''
          export PLEX_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/plex-token")"
          exec ${lib.getExe pkgs.mcp-proxy} \
            --host 0.0.0.0 \
            --port ${toString cfg.port} \
            --pass-environment \
            -- ${lib.getExe pkgs.customPkgs.plex-mcp-server}
        '';

        DynamicUser = true;
        LoadCredential = [ "plex-token:${cfg.tokenFile}" ];

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
        # Node/V8 JIT maps RWX pages — W^X must stay off (same as litellm-router).
        MemoryDenyWriteExecute = false;
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];

        # Resource limits
        MemoryMax = "512M";
        TasksMax = 128;

        # Reliability
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Open the port ONLY on tailscale0 (+ optional LAN iface). Never added to
    # the global allowedTCPPorts.
    networking.firewall.interfaces = lib.mkMerge [
      { "tailscale0".allowedTCPPorts = [ cfg.port ]; }
      (lib.mkIf (cfg.listenLanInterface != null) {
        "${cfg.listenLanInterface}".allowedTCPPorts = [ cfg.port ];
      })
    ];
  };
}
