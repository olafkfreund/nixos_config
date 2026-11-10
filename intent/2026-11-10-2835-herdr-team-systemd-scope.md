---
status: draft
issue: 2835
author: olafkfreund
---

# Intent: contain each herdr-team member in a systemd scope

## Problem

Issue #2818 made `stop_member` stop a member's processes by process group plus a `HERDR_TEAM_MEMBER` marker. The live
check on p620 (2026-11-10) showed this cannot reach the commands a Codex member runs:

- Codex starts each shell command in its own new session and process group (`pgrp == sid`), outside the member's
  group.
- Those commands' environment has no `HERDR_TEAM_MEMBER`.

Today that is masked: a graceful `finish` makes Codex end its own background commands. A Codex that crashes,
hangs, or is ended by the watchdog or by `down --force` leaves them running, for example a `sleep 600 &` or a
long build. #2828 adds agy members, whose tool processes may behave the same way.

A probe on p620 confirmed the alternative. A transient user scope (`systemd-run --user --scope`) kept a `setsid`
child in its cgroup, and stopping the scope ended it.

## Proposed outcome

- Every herdr-team member, Codex now and agy after #2828, runs inside its own transient systemd user scope named
  after the task, generation and member.
- `finish`, `down` and `sweep` end every process of a member that is still running, whatever its session,
  process group or environment, and never a process outside that member's scope.
- A crashed or force-stopped member leaves nothing behind.
- If user systemd is unavailable (no user manager, no session bus), herdr-team falls back to today's
  marker-and-group stop and says so in its output, instead of failing.

## Affected users and systems

- `home/development/herdr-team.sh`: the launcher, `stop_member`, `sweep`, `teardown` and the watchdog.
- `home/development/herdr-team-test.sh`, which today runs without user systemd; the Nix build sandbox has none.
- `docs/applications/herdr.md`.
- p620 and razer, both running a user systemd manager. p510 is not touched.

## Constraints

- **Containment, not a sandbox.** No resource limits, no filesystem or network restriction, no new sandboxing.
  Members stay unrestricted (#2812).
- **No secrets.** The scope must not change which environment the member gets: `agent-env` and the key strip
  lists stay as they are.
- **Visibility.** The member still runs in its visible herdr pane, with the same terminal and the same
  `ctrl+c`-based graceful quit.
- **Bus announcements.** Stopping a member's own scope is part of herdr-team's normal teardown, not a host
  disruption. The `systemctl --user stop` it issues must not need a bus announcement each time. Today the
  guard blocks that command.
- **Only the member's scope.** herdr-team never stops a scope it did not create: scope names are unique and
  recorded in the state file.
- **Ordering.** It lands after #2829 and before #2828, which then reuses it for agy.

## Open questions

- **The bus guard.** Should it exempt `systemctl --user stop herdr-team-*.scope` by pattern, or should
  herdr-team stop its scopes through a path the guard does not match (for example the D-Bus `StopUnit` call)?
  Default: a narrow guard exemption for exactly that unit-name pattern.
- **The fallback** without user systemd: keep #2818's marker path, or refuse to start a member? Default: keep the
  marker path and report `containment: "group"` in `up`'s output, so the test suite and hosts without a user
  manager still work.
