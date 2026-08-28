{ config, lib, pkgs, ... }:
# Periodic backup of SQLite databases to durable storage.
#
# The library database holds every watch state, rating, collection and piece of
# curated metadata — the one thing on this host that cannot be re-acquired. It
# lives under services.plex.dataDir, which on p510 is /mnt/media, i.e. the
# 12TB ST12000NM0127 (ZJV2NZE9) that has been shedding sectors since August
# 2026: 2896 reallocated and 656 currently-pending at the time of writing,
# while SMART still self-assesses as PASSED. There is no RAID and no other
# copy — a scan on 2026-08-21 found nothing resembling a Plex backup anywhere
# on the healthy disks.
#
# `sqlite3 .backup`, not cp: these databases run in WAL mode (the -wal/-shm
# files sit right beside them), so copying the .db alone captures a torn state
# missing everything still in the write-ahead log. The backup API takes a
# consistent snapshot of a database that is actively being written, so Plex
# keeps running throughout.
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.features.sqlite-backup;

  plexDbDir = "${config.services.plex.dataDir}/Plex Media Server/Plug-in Support/Databases";
in
{
  options.features.sqlite-backup = {
    enable = mkEnableOption "Periodic sqlite backup of application databases";

    databases = mkOption {
      type = types.listOf types.str;
      default = [
        "${plexDbDir}/com.plexapp.plugins.library.db"
        "${plexDbDir}/com.plexapp.plugins.library.blobs.db"
      ];
      description = ''
        Absolute paths of the SQLite databases to snapshot. A missing file is
        skipped with a warning rather than failing the run, so a service that
        has not started yet does not break the others.
      '';
    };

    readPaths = mkOption {
      type = types.listOf types.str;
      default = [ config.services.plex.dataDir ];
      description = ''
        Directories the unit may read. ProtectSystem=strict hides everything
        else, so any path holding a listed database must appear here.
      '';
    };

    optional = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Databases whose failure must not fail the run. For a source sitting on
        known-bad media: the read is still attempted every night — a pending
        sector sometimes becomes readable again, and a reallocation on write
        can retire it — but an unrecoverable error is logged as a warning
        rather than turning the unit red. Reserve this for data that can be
        rebuilt; a database listed here is one nobody is watching.
      '';
    };

    readGroups = mkOption {
      type = types.listOf types.str;
      default = [ config.services.plex.group ];
      description = ''
        Groups the unit joins. Every directory on the path to a listed database
        must be traversable by one of them: a DynamicUser belongs to no group
        by default, and a 0700 service data directory turns a perfectly
        readable database into "not found" from inside the namespace — the
        stat fails on the directory, not the file.
      '';
    };

    destination = mkOption {
      type = types.str;
      default = "/mnt/img_pool/backups/sqlite";
      description = ''
        Where snapshots are written. MUST be a different physical disk from
        services.plex.dataDir — the entire point is surviving that disk.
      '';
    };

    keep = mkOption {
      type = types.int;
      default = 7;
      description = "How many timestamped snapshots to retain.";
    };

    dates = mkOption {
      type = types.str;
      default = "03:30";
      description = ''
        systemd OnCalendar expression. Defaults to a quiet hour: the backup
        reads ~1GB off a disk that is already struggling, so it should not
        compete with evening playback.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(lib.any (rp: lib.hasPrefix rp cfg.destination) cfg.readPaths);
        message =
          "features.sqlite-backup.destination (${cfg.destination}) sits inside one "
          + "of readPaths. A backup on the same disk as the original protects "
          + "against nothing — the whole point is surviving that disk.";
      }
    ];

    # 0770 root:plex so the DynamicUser can write via SupplementaryGroups.
    systemd.tmpfiles.rules = [
      "d ${cfg.destination} 0770 root ${config.services.plex.group} - -"
    ];

    systemd.services.sqlite-backup = {
      description = "Back up application SQLite databases to durable storage";
      after = [ "plex.service" ];
      path = with pkgs; [ sqlite coreutils ];

      serviceConfig = {
        Type = "oneshot";

        # The databases are mode 0644, but not every directory holding one is
        # traversable by a stranger: the *arr data directories are 0700. The
        # groups are needed to read those, and to WRITE into the destination,
        # whose owner cannot be pinned to a UID that changes on every run.
        DynamicUser = true;
        SupplementaryGroups = cfg.readGroups;

        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ReadOnlyPaths = cfg.readPaths;
        ReadWritePaths = [ cfg.destination ];
      };

      script = ''
        # nixpkgs prepends `set -e` to every systemd `script`, and this one is
        # built the other way round: each database is attempted, failures are
        # accumulated in rc, and the run reports them at the end. Left on, the
        # first `ls` in the prune loop that matches nothing exits 2 —
        # pipefail propagates it, -e aborts — and the unit dies before
        # `exit "$rc"`, red for a database that has simply never been
        # snapshotted yet.
        set +e
        set -uo pipefail
        ts=$(date +%Y%m%d-%H%M%S)
        rc=0

        is_optional() {
          for o in ${lib.escapeShellArgs cfg.optional}; do
            [ "$o" = "$1" ] && return 0
          done
          return 1
        }

        for src in ${lib.escapeShellArgs cfg.databases}; do
          db=$(basename "$src")
          if [ ! -f "$src" ]; then
            # Not "not found": -f is equally false when the file is there but
            # its directory is not traversable from inside the namespace, and a
            # message claiming absence sends you looking for the wrong bug.
            echo "[sqlite-backup] $src unreadable (missing, or its directory is not traversable by this unit); skipping" >&2
            continue
          fi

          out="${cfg.destination}/''${db%.db}-$ts.db"
          # No `pragma integrity_check` afterwards: Plex builds its databases
          # with custom collations, and a stock sqlite3 aborts with "unknown
          # tokenizer: collating" before it checks anything. That is a property
          # of the reader, not damage to the file — .backup copies at the page
          # level, and the snapshot queries fine (verified against
          # metadata_items on 2026-08-21). A check that always fails would
          # train you to ignore the one that matters.
          if sqlite3 "$src" ".backup '$out'"; then
            echo "[sqlite-backup] $db -> $(basename "$out") ($(stat -c %s "$out") bytes)"
          elif is_optional "$src"; then
            echo "[sqlite-backup] WARNING: $db unreadable, continuing (listed as optional)" >&2
            rm -f "$out"
          else
            echo "[sqlite-backup] ERROR: backup of $src failed" >&2
            rm -f "$out"
            rc=1
          fi
        done

        # Prune per database, so one large file cannot evict another's history.
        for src in ${lib.escapeShellArgs cfg.databases}; do
          db=$(basename "$src")
          ls -1t "${cfg.destination}/''${db%.db}"-2*.db 2>/dev/null \
            | tail -n +${toString (cfg.keep + 1)} \
            | xargs -r rm -f
        done

        exit "$rc"
      '';
    };

    systemd.timers.sqlite-backup = {
      description = "Periodic application database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dates;
        # Catch up after the host has been down — this box loses power.
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
}
