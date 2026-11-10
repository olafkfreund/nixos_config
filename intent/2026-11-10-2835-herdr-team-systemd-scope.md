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

- **With user systemd** (p620 and razer): every herdr-team member, Codex now and agy after #2828, runs inside its
  own transient user scope, named after the task, generation and member and recorded in the state file.
  - Every process the member started is ended, whatever its session, process group or environment, and never
    a process outside that scope. That happens at each of these points:
    - when the member's main process exits, including a crash, at the launcher's exit;
    - when the watchdog fires;
    - on `finish`, `down` and `sweep`.
  - A launcher that is itself killed outright is caught by the next `sweep`, which every `up` runs.
  - The stop keeps today's bound: TERM, then KILL after about 5 s, scaled by `HERDR_TEAM_TIME_SCALE`. Never
    systemd's default 90 s.
- **Without user systemd** (no user manager or session bus), herdr-team keeps #2818's group-and-marker stop. That
  mode is weaker: commands that leave the group or drop the marker can survive. So `up` reports
  `containment: "group"` instead of `"scope"`, and the docs say what that mode misses.

## Affected users and systems

- `home/development/herdr-team.sh`: the launcher, `stop_member`, `sweep`, `teardown` and the watchdog;
  `home/development/agent-run.nix`, which may need `systemd` on the script's runtime path.
- `home/development/herdr-team-test.sh`, which today runs without user systemd; the Nix build sandbox has none.
- `docs/applications/herdr.md`.
- p620 and razer, both running a user systemd manager.
- p510 imports the same Home Manager config, so it gets the change at its next deploy, which needs the owner's
  OK. It is not built or deployed here.

## Constraints

- **Containment, not a sandbox.** No resource limits, no filesystem or network restriction, no new sandboxing.
  Members stay unrestricted (#2812).
- **No secrets.** The scope must not change which environment the member gets: `agent-env` and the key strip
  lists stay as they are.
- **Visibility.** The member still runs in its visible herdr pane, with the same terminal and the same
  `ctrl+c`-based graceful quit.
- **Bus announcements.** The bus guard inspects only the command text of Claude's own Bash tool calls, so it
  never sees the scope stop that herdr-team runs internally. Stopping a member's own scope is normal teardown, not
  a host disruption.
  - The guard is not changed.
  - No exemption is added: an exemption by unit-name pattern would let any agent stop matching scopes without
    the bus.
  - A direct `systemctl` call by an agent still needs the announcement.
- **The launcher records exit first.** The scope must not end the launcher before it writes `$ctl/status` and
  `$ctl/exit`. Stopping the scope must not flood `$ctl/stderr`.
- **Only the member's scope.** herdr-team never stops a scope it did not create: scope names are unique and
  recorded in the state file.
- **Ordering.** It lands after #2829 and before #2828, which then reuses it for agy.

## Open questions

- **Terminal and job control inside a scope.** The launcher relies on `set -m` to give the member the pane's
  foreground process group. That is what makes `ctrl+c` in the pane, and `finish`'s graceful quit, reach the
  member. Does starting the member inside a scope keep that?
  - The `setsid` probe on p620 proved containment only, not terminal behaviour.
  - Default: the spec must keep the member in the pane's terminal session. The outcome is met only after a live
    pane check on p620, where `ctrl+c` and `finish` behave as today.
- **What the scope wraps:** the whole launcher, or only the member command? Default: only the member command,
  so the launcher stays outside, records the exit, and stops the scope.
