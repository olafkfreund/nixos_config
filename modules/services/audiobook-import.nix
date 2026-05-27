# audiobook-import — completed-download → Audiobookshelf import pipeline.
#
# A timer-driven reconciler (modules/services/audiobook-import.py) that scans
# the audiobook download dir(s) for stable, completed folders, uses the local
# Ollama to parse the release name into structured metadata, optionally merges
# multi-file books into a chaptered M4B via m4b-tool, and hardlinks/places the
# result into the Audiobookshelf library with a metadata.json. Idempotent via
# a `.imported` marker; sources are left intact so torrent seeding continues.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.audiobook-import;

  worker = pkgs.writers.writePython3Bin "audiobook-import"
    {
      # Cosmetic flake8 codes only (line length, whitespace); logic is checked
      # by py_compile. E722/BLE001-style broad excepts are intentional here.
      flakeIgnore = [ "E501" "E265" "E266" "W503" "W504" "E203" ];
    }
    (builtins.readFile ./audiobook-import.py);
in
{
  options.features.audiobook-import = {
    enable = lib.mkEnableOption "audiobook download → Audiobookshelf import pipeline";

    watchDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/media/downloads/torrents/audiobooks" ];
      description = "Download directories scanned for completed audiobook folders.";
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/Media/Audiobooks";
      description = "Audiobookshelf library root to place imported books into.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5:7b";
      description = "Ollama model used for metadata extraction (strict JSON).";
    };

    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:11434";
      description = "Base URL of the local Ollama server.";
    };

    mergeToM4b = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Merge multi-file audiobooks into a single chaptered M4B via m4b-tool.";
    };

    stableSeconds = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "Skip folders modified more recently than this (still downloading).";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/5";
      description = "systemd OnCalendar expression for the import scan (default every 5 min).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "olafkfreund";
      description = "User to run the import as (must own the library + read downloads).";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group to run the import as.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.audiobook-import = {
      description = "Audiobook download → Audiobookshelf import";
      after = [ "network-online.target" "ollama.service" ];
      wants = [ "network-online.target" ];

      environment = {
        AUDIOBOOK_WATCH_DIRS = lib.concatStringsSep ":" cfg.watchDirs;
        AUDIOBOOK_LIBRARY_DIR = cfg.libraryDir;
        OLLAMA_URL = cfg.ollamaUrl;
        OLLAMA_MODEL = cfg.model;
        M4B_TOOL = lib.getExe pkgs.customPkgs.m4b-tool;
        MERGE_TO_M4B = if cfg.mergeToM4b then "1" else "0";
        STABLE_SECONDS = toString cfg.stableSeconds;
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe worker;
        User = cfg.user;
        Group = cfg.group;

        # Hardening — needs write to the media pool and localhost Ollama access.
        ProtectSystem = "strict";
        ReadWritePaths = [ "/mnt/media" ];
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      };
    };

    systemd.timers.audiobook-import = {
      description = "Periodic audiobook import scan";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = 30;
      };
    };
  };
}
