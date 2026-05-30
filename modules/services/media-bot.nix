# media-bot — household Telegram bot for the *arr stack on p510.
#
# Phase 1 surface (spec: docs/plans/2026-05-30-media-bot-design.md, mirrored
# at ~/.claude/plans/stateless-enchanting-beaver.md during brainstorm):
#   • menu commands (/search /add /queue /status /recent /wanted)
#   • aiohttp webhook receiver on cfg.port ingesting Sonarr / Radarr /
#     Overseerr / audiobook-import events; replies to Telegram with inline
#     action buttons (Quiet event set — wins only).
#   • Ollama-backed natural-language fallback (qwen2.5:7b by default,
#     override via OLLAMA_MODEL in the env file).
#
# Required secrets (both agenix-encrypted, host-keyed for p510):
#   • media-bot-env.age   — TELEGRAM_BOT_TOKEN + *arr API keys + OLLAMA_*
#   • media-bot-users.age — YAML user whitelist (telegram_id, plex_user, name)
#
# Pattern mirrors modules/services/arr-suite-mcp.nix: DynamicUser, full
# systemd hardening, tailscale-only firewall by default.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.media-bot;
in
{
  options.features.media-bot = {
    enable = lib.mkEnableOption "household media Telegram bot";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = ''
        Port the aiohttp webhook receiver listens on. Loopback is always
        available; the firewall opens this port on `tailscale0` (and
        optionally on a named LAN interface) so Sonarr / Radarr / Overseerr
        and audiobook-import.service can POST event payloads to it.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."media-bot-env".path;
      defaultText = lib.literalExpression
        ''config.age.secrets."media-bot-env".path'';
      description = ''
        EnvironmentFile with TELEGRAM_BOT_TOKEN, *arr API keys, OLLAMA_*
        endpoint + model (KEY=VALUE per line). The bot reads these on
        startup; restart the service to pick up changes.
      '';
    };

    usersFile = lib.mkOption {
      type = lib.types.path;
      default = config.age.secrets."media-bot-users".path;
      defaultText = lib.literalExpression
        ''config.age.secrets."media-bot-users".path'';
      description = ''
        YAML file listing whitelisted Telegram users and their Plex
        usernames. Reloadable at runtime: `systemctl reload media-bot`
        sends SIGHUP, the bot rereads this file, no restart needed.
      '';
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to additionally open `cfg.port` on. `null` exposes
        the webhook receiver only via tailscale0 — recommended, since
        Sonarr / Radarr / Overseerr / audiobook-import all run on the
        same host as the bot and reach it via 127.0.0.1.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."media-bot-env" = {
      file = ../../secrets/media-bot-env.age;
      mode = "0400";
    };
    age.secrets."media-bot-users" = {
      file = ../../secrets/media-bot-users.age;
      mode = "0400";
    };

    systemd.services.media-bot = {
      description = "Household media Telegram bot (menu + Ollama NL + webhooks)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        # BOT_USERS_FILE points into the systemd Credentials Directory
        # populated by LoadCredential below — agenix decrypts the YAML
        # as root to /run/agenix/media-bot-users (0400 root-owned), then
        # systemd copies it into /run/credentials/media-bot.service/
        # readable by the DynamicUser-spawned bot process. Same pattern
        # plex-mcp uses for PLEX_TOKEN.
        BOT_USERS_FILE = "/run/credentials/media-bot.service/users-file";
        WEBHOOK_PORT = toString cfg.port;
      };

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.customPkgs.media-bot}";
        EnvironmentFile = cfg.environmentFile;
        LoadCredential = [ "users-file:${cfg.usersFile}" ];

        DynamicUser = true;
        StateDirectory = "media-bot";
        StateDirectoryMode = "0700";

        # SIGHUP triggers the bot's in-process whitelist reload.
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

        # Hardening — mirrors modules/services/arr-suite-mcp.nix (docs/
        # PATTERNS.md security baseline).
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
        # CPython + native httpx/aiohttp map RWX; keep W^X off
        # (matches arr-suite-mcp precedent).
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
