---
status: draft
issue: 2188
intent: intent/2026-10-06-2188-backup-silent-skip.md
---

# Spec: a missed k3d backup is noticed

## Decisions carried from the intent approval

1. Alert channel: a **failed systemd unit and a desktop notification**.
2. The in-cluster factory `postgres-backup` CronJob is covered by the same
   host-side check.
3. Threshold: alert when the newest backup is **older than 36 h**. The jobs
   run daily, so one skipped run never alerts.

## Design

All changes are in `modules/containers/k3d.nix`, under the existing
`mkIf cfg.argocd.enable` block, beside the backup units.

### 1. Skips always say why

The silent skip paths become logged skips that still exit 0:

- `skillai-db-backup`: `kubectl get pod … || exit 0`.
- `keycloak-realm-backup`: `kubectl get pvc … || exit 0`.

Each logs one line, for example
`[skillai-backup] cluster unreachable; skipping`. Skipping stays
non-fatal: detecting a missed backup is the freshness check's job, not the
backup run's.

### 2. One freshness check: `k3d-backup-freshness`

A root oneshot service plus an hourly timer (`Persistent = true`), using
the backup units' pattern (`path = [ kubectl coreutils ]`,
`environment.KUBECONFIG`). It checks three sources against
`maxAge = 36h`:

| Backup | Signal |
|---|---|
| skillai | mtime of `<backups>/skillai/skillai-latest.dump` |
| keycloak | mtime of `<backups>/keycloak/keycloakdb-latest.mv.db` |
| factory postgres | `.status.lastSuccessfulTime` of CronJob `factory/postgres-backup` |

It logs one line per source (`ok` or `STALE … last <date>`). It exits 1 if
any source is stale or its signal is missing. An unreachable cluster means
the CronJob signal is missing, which counts as stale: a cluster down for
36 h is itself worth an alert.

The threshold is a module option, `backupMaxAgeHours` (default 36), so it
is not a magic number in the script.

### 3. The alert: `OnFailure`, then a desktop notification

`k3d-backup-freshness` has
`unitConfig.OnFailure = [ "k3d-backup-alert.service" ]`. That oneshot sends
a desktop notification to every logged-in graphical user. It loops over
`/run/user/<uid>/bus` for uids of 1000 and above, and runs
`runuser -u <user> -- notify-send -u critical "k3d backups stale" "<summary>"`
with that bus. The summary is the STALE lines from the failed run's journal.
`libnotify` is added to its `path`.

The failed unit stays visible in `systemctl --failed` and `nixos-doctor`
until a later run passes. That is the persistent signal, and the
notification is the immediate one.

## Alternatives rejected

- **Make each backup unit fail on skip.** A normal startup skip would then
  page, which the intent rules out.
- **Prometheus or Alertmanager.** Monitoring was removed from this repo.
- **List the MinIO bucket from the host to date the Postgres dumps.** That
  needs MinIO credentials on the host. The CronJob's
  `lastSuccessfulTime` is the same fact without a secret.
- **A user-level timer.** Backups and kubeconfig are root-owned, and the
  check must run with nobody logged in. Only the notification step needs
  the user session.

## Risks

- **The first run after deploy alerts.** The latest skillai and keycloak
  dumps are from 2026-10-05, more than 36 h old by tomorrow if the nightly
  runs skip again. That is a true positive, and the verification step
  triggers fresh backups first.
- **No graphical session.** Nobody is notified, but the failed unit
  remains. That is acceptable.
- **The CronJob is renamed in factory-gitops.** The check reports
  "missing" and alerts, which is visible rather than silent.

## Verification

- `just test-host p620` builds.
- Start both backup units by hand. Each writes a fresh dump, and
  `k3d-backup-freshness` logs three `ok` lines and exits 0.
- Stale path, tested non-destructively: run the check with
  `backupMaxAgeHours` overridden to 0 through `systemd-run` with the
  script and an environment override. It exits 1 and the desktop
  notification appears.
- `systemctl list-timers k3d-backup-freshness` shows the hourly schedule.
