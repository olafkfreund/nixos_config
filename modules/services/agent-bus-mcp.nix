# agent-bus-mcp — the shared room for coding agents, as MCP tools.
#
# Wraps the stdio server in pkgs/agent-bus-mcp with mcp-proxy (stdio→SSE) so it
# is reachable from other machines, exactly as plex-mcp, arr-suite-mcp and
# audiobook-mcp do. Clients connect to http://<host>:<port>/sse.
#
# This replaces the SSH bulletin board as the agent channel. The board is a
# human terminal UI, so every agent using it had to impersonate a terminal:
# no PTY meant no reading, identity meant provisioning an SSH key per agent,
# and it took a long skill just to list which routes would refuse. Here an
# agent gets `post` and `read_new` as tools it already knows how to call, and
# any MCP-speaking model works — that is the reason for the change.
#
# Tailnet-only, like its three siblings. The Cloudflare tunnel adds no
# authentication of its own, and this endpoint has none either: anything that
# can reach the port can post as this host's agent. The Matrix side is the
# public face, where accounts and passwords do the gating.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.agent-bus-mcp;
in
{
  options.features.agent-bus-mcp = {
    enable = lib.mkEnableOption "agent bus MCP server (SSE daemon via mcp-proxy)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3013;
      description = ''
        Port the SSE bridge binds to. 3010-3012 are the plex, arr-suite and
        audiobook MCP daemons; this continues the row.
      '';
    };

    homeserver = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:6167";
      description = "Matrix homeserver base URL. Loopback: the two run together.";
    };

    agentName = lib.mkOption {
      type = lib.types.str;
      example = "agent-p510";
      description = ''
        Identity this daemon posts under, and the key its read cursors are
        stored against.

        One name per daemon, not per caller: the SSE endpoint has no
        per-client authentication, so everything reaching this port shares
        this identity. That is honest on a tailnet and would not be on the
        public internet — giving individual agents their own identities means
        per-agent tokens and an authenticating proxy in front.
      '';
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."agent-bus-matrix-token".path;
      defaultText = lib.literalExpression ''config.age.secrets."agent-bus-matrix-token".path'';
      description = ''
        File holding the Matrix access token for `agentName`, from
        `POST /_matrix/client/v3/login`. Matrix access tokens do not expire
        unless refresh tokens were requested, so this is set once.
      '';
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to open the port on, in addition to tailscale0. `null`
        keeps the bus tailnet-only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."agent-bus-matrix-token" = {
      file = ../../secrets/agent-bus-matrix-token.age;
      mode = "0400";
    };

    systemd.services.agent-bus-mcp = {
      description = "Agent bus MCP server (shared Matrix room, SSE via mcp-proxy)";
      after = [ "network-online.target" "continuwuity.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        MATRIX_HOMESERVER = cfg.homeserver;
        AGENT_BUS_NAME = cfg.agentName;
      };

      serviceConfig = {
        # The token is read from the credential directory rather than an
        # EnvironmentFile so the secret never becomes a file the service user
        # can read directly; systemd projects it as root, same as plex-mcp.
        ExecStart = pkgs.writeShellScript "agent-bus-mcp-start" ''
          export MATRIX_ACCESS_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/matrix-token")"
          exec ${lib.getExe pkgs.mcp-proxy} \
            --host 0.0.0.0 \
            --port ${toString cfg.port} \
            --pass-environment \
            -- ${lib.getExe pkgs.customPkgs.agent-bus-mcp}
        '';
        LoadCredential = [ "matrix-token:${cfg.tokenFile}" ];

        DynamicUser = true;
        StateDirectory = "agent-bus-mcp";
        StateDirectoryMode = "0700";

        # Hardening — docs/PATTERNS.md security baseline, matching
        # modules/services/arr-suite-mcp.nix.
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
        # CPython maps RWX; matches the other MCP daemons here.
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
