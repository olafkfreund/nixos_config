---
status: approved
issue: 2188
author: olafkfreund
---

# Intent: a missed k3d backup is noticed

## Problem

The p620 backup timers `skillai-db-backup` and `keycloak-realm-backup`
(`modules/containers/k3d.nix`) exit 0 whenever they cannot take a backup:
the cluster is down, the pod is not Running, or `pg_dump` failed. Skipping
one run while the cluster starts is reasonable. The problem is that nothing
notices when backups stop altogether.

- On 2026-10-06 at 00:24, k3d was down. `skillai-db-backup` exited 0 in
  68 ms, wrote nothing and logged nothing (the `kubectl get … || exit 0` path
  is silent).
- The newest skillai dump is from 2026-10-05 08:53, and no alert fired.
- The factory Postgres backup, a separate in-cluster CronJob, missed
  2026-10-05 entirely: a stuck Job blocked the CronJob, and nothing reported
  it.

## Proposed outcome

- When the newest dump of any k3d backup is older than its expected
  interval plus a grace period, the failure is visible: a failed unit, and
  ideally a desktop notification.
- Every skipped run logs why it skipped.
- A single skipped run during startup still does not raise an alarm.

## Affected users and systems

- p620 only: `modules/containers/k3d.nix` (skillai and keycloak backup
  units), backup directories under `/mnt/data/k3d/backups`.
- Possibly the in-cluster `postgres-backup` CronJob (factory-gitops repo)
  for the same staleness check.

## Constraints

- Monitoring was removed (no Prometheus or Alertmanager). Use systemd unit
  state, `journalctl`, and the desktop notifications that already exist.
- Do not make a normal startup skip fail the unit.
- Services follow the module rules (`modules/`, `features.<name>.enable`,
  hardening). The existing backup units are root units inside the k3d
  module; changes stay there.

## Open questions

1. What is the alert channel: a failed systemd unit only, a desktop
   notification (`omarchy-notification-send`), or both?
2. Should the in-cluster factory `postgres-backup` CronJob get the same
   staleness check from the host side, or is that a separate factory-gitops
   issue?
3. What staleness thresholds: skillai and keycloak back up daily, so is
   alerting at 36 hours right?

## Decisions at approval

The user approved on 2026-10-06 with the recommended answers to every open
question, as listed in the session reply.
