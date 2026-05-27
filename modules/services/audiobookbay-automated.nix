# audiobookbay-automated — AudioBookBay search → Transmission web app.
#
# A small Flask app (pkgs.customPkgs.audiobookbay-automated) that searches
# AudioBookBay and sends the chosen release's magnet to the existing
# Transmission daemon on p510. Each download is saved to
# <savePathBase>/<Title>/, which the audiobook-import pipeline watches.
#
# The app only talks to Transmission's RPC (127.0.0.1:9091, auth disabled on
# p510) and to AudioBookBay over HTTPS — it writes nothing to disk itself, so
# the unit runs fully sandboxed (DynamicUser + ProtectSystem=strict).
#
# Note: AudioBookBay distributes copyrighted material without authorization.
# abbHostname is configurable; the same app works against any compatible host.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.audiobookbay-automated;
in
{
  options.features.audiobookbay-automated = {
    enable = lib.mkEnableOption "AudioBookBay search → Transmission web app";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5078;
      description = "Port the Flask UI binds to (loopback always; tailnet + LAN via firewall).";
    };

    abbHostname = lib.mkOption {
      type = lib.types.str;
      default = "audiobookbay.lu";
      description = "AudioBookBay host to search against.";
    };

    transmissionHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Transmission RPC host.";
    };

    transmissionPort = lib.mkOption {
      type = lib.types.port;
      default = 9091;
      description = "Transmission RPC port.";
    };

    savePathBase = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/downloads/torrents/audiobooks";
      description = ''
        Base directory passed to Transmission as the per-torrent download
        location (each book lands in <savePathBase>/<Title>/). Must be
        writable by the Transmission service user; watched by the
        audiobook-import pipeline.
      '';
    };

    category = lib.mkOption {
      type = lib.types.str;
      default = "Audiobookbay-Audiobooks";
      description = "Download category/label tag.";
    };

    listenLanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eno1";
      description = ''
        LAN interface to open the port on, in addition to tailscale0 and
        loopback. null exposes the UI only via Tailscale.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.audiobookbay-automated = {
      description = "AudioBookBay search → Transmission web app";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        PORT = toString cfg.port;
        ABB_HOSTNAME = cfg.abbHostname;
        DOWNLOAD_CLIENT = "transmission";
        DL_SCHEME = "http";
        DL_HOST = cfg.transmissionHost;
        DL_PORT = toString cfg.transmissionPort;
        DL_CATEGORY = cfg.category;
        SAVE_PATH_BASE = cfg.savePathBase;
      };

      serviceConfig = {
        ExecStart = lib.getExe pkgs.customPkgs.audiobookbay-automated;

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
        # CPython maps RWX in places; keep W^X off (matches arr-suite-mcp).
        MemoryDenyWriteExecute = false;
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];

        MemoryMax = "256M";
        TasksMax = 64;

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
