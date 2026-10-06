---
status: approved
issue: 2188
spec: spec/2026-10-06-2188-backup-silent-skip.md
---

# Plan: a missed k3d backup is noticed

## Approved decisions (carried from the spec)

- **Alert.** A failed systemd unit plus a critical desktop notification.
- **Coverage.** The skillai dump, the keycloak dump, and the in-cluster
  CronJob `factory/postgres-backup`. For the CronJob, read
  `.status.lastSuccessfulTime` instead of listing MinIO.
- **Threshold.** 36 h, as a module option `backupMaxAgeHours` (default 36).
  The jobs run daily, so one skipped run never alerts.
- **Skips.** Skipping stays exit 0, but every skip path logs why.
- **No Prometheus or Alertmanager.** Monitoring was removed.

## Facts the steps rely on

- **Backup units.** All live in `modules/containers/k3d.nix`, inside
  `config = mkIf cfg.enable` (line 753) and guarded by
  `mkIf cfg.argocd.enable`. They are root oneshots with
  `path = with pkgs; [ kubectl coreutils ]` and
  `environment.KUBECONFIG = cfg.kubeconfigPath`.
- **Backup directory.** It is
  `${builtins.dirOf (toString cfg.storageDir)}/backups/<name>`; the latest
  files are `skillai/skillai-latest.dump` and
  `keycloak/keycloakdb-latest.mv.db`.
- **The silent skips.** `k3d.nix:863` (keycloak: `kubectl get pvc … || exit 0`)
  and `k3d.nix:949` (skillai: `kubectl get pod … || exit 0`).
- **Option anchors.** `storageDir` at 625, `kubeconfigPath` at 637,
  `argocd` at 658, `imageGc` at 741.
- **Ordering.** #2187 adds a unit after line 976. Rebase this branch on
  main after #2187 merges, and re-find every line by its content.

## Steps

1. **`k3d.nix:863` and `k3d.nix:949`: log the silent skips.**
   Replace `|| exit 0` with
   `|| { echo "[keycloak-backup] cluster unreachable; skipping" >&2; exit 0; }`,
   and the same with the `[skillai-backup]` prefix.
   Check: `just check-syntax`.
   Traps: in Nix `''` strings, `${` stays as written here (no Nix
   interpolation).

2. **`k3d.nix`, after the `kubeconfigPath` option (line 637 block): the
   threshold option.**
   `backupMaxAgeHours = mkOption { type = types.ints.positive; default = 36;
   description = "Alert when the newest k3d backup is older than this."; };`
   Check: `just check-syntax`.

3. **`k3d.nix`, after the last backup timer: the freshness check and its
   alert.**
   - `systemd.services.k3d-backup-freshness` (mkIf `cfg.argocd.enable`):
     - root oneshot, the skillai pattern, plus
       `unitConfig.OnFailure = [ "k3d-backup-alert.service" ]`;
     - the script sets
       `max=''${MAX_AGE_SECONDS:-$(( ${toString cfg.backupMaxAgeHours} * 3600 ))}`.
       The optional environment override exists only for the stale-path
       test. It also sets `now=$(date +%s)` and `stale=0`;
     - for each dump file: if it is missing, or `now - $(stat -c %Y file) > max`,
       echo `STALE <name> last <date>` and set `stale=1`; otherwise echo
       `ok <name> <date>`;
     - for the CronJob: `t=$(kubectl -n factory get cronjob postgres-backup -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null)`;
       empty means STALE ("missing or cluster unreachable"); otherwise
       compare `date -d "$t" +%s` the same way;
     - `exit $stale`.
   - `systemd.timers.k3d-backup-freshness`:
     `OnCalendar = "hourly"; Persistent = true;`.
   - `systemd.services.k3d-backup-alert`: a root oneshot with
     `path = with pkgs; [ libnotify util-linux coreutils systemd gnugrep ]`.
     Its script:
     - takes the summary from
       `journalctl -u k3d-backup-freshness -n 20 -o cat | grep STALE`;
     - loops `for bus in /run/user/*/bus`;
     - sets `uid` from the path, and skips uids below 1000;
     - sets `user=$(id -nu "$uid")`;
     - runs:

       ```bash
       runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
         notify-send -u critical "k3d backups stale" "$summary"
       ```

   Check: `just test-host p620` builds.
   Traps: the alert unit must not itself fail when nobody is logged in.
   End its script with `exit 0`.

4. **Ship.**
   - Rebase on main after #2187 merges, and rebuild.
   - Commit `fix(k3d): alert when k3d backups go stale (#2188)` and open a
     PR linking intent, spec and plan.
   - Merge after CI, post to the bus, then `nh os switch` p620 from main.

   Checks:
   - `systemctl start skillai-db-backup keycloak-realm-backup` writes fresh
     dumps.
   - `systemctl start k3d-backup-freshness` logs three `ok` lines and
     exits 0.
   - **Stale path:** run `systemctl set-environment MAX_AGE_SECONDS=0`,
     start `k3d-backup-freshness`, then
     `systemctl unset-environment MAX_AGE_SECONDS`. It must exit 1,
     `k3d-backup-alert` must run, and the notification must appear.
   - `systemctl list-timers k3d-backup-freshness` shows the hourly
     schedule.
   - main's p620 toplevel equals `/run/current-system`.

   Traps: merge before 04:00 (the auto-upgrade switches from main).

## Tests

- `just check-syntax` and `just test-host p620` pass.
- The healthy path: three `ok` lines and exit 0.
- The stale path: exit 1, the alert unit runs, and the desktop notification
  appears.
- A skip path: with the cluster unreachable, which can't be faked safely,
  check by reading the journal after the next real skip. Not a gate.

## Rollback

Revert the PR and switch. The units are removed, and the skip-logging
change is cosmetic.
