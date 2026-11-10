---
status: draft
issue: 2835
intent: intent/2026-11-10-2835-herdr-team-systemd-scope.md
---

# Spec: contain each herdr-team member in a systemd scope

## Design

All changes are in `home/development/herdr-team.sh` (the launcher heredoc, `stop_member`, `teardown`, `sweep`,
`up`), `home/development/agent-run.nix`, the test and the docs.

### Facts this rests on (probed on p620, systemd 262)

- `systemd-run --user --scope` registers the scope for its own PID and then `exec`s the command. The inner process
  had the job's PID and process group and stayed on the same pts.
- With `-p TimeoutStopSec=2`, `systemctl --user stop` ended a `setsid` child that ignored TERM after 2.1 s
  (KillMode `control-group`), and the unit was gone afterwards.
- **Trap:** systemd-run expands `$VAR` in its command line by default; `$$` reached the command as `$`. Every call
  passes `--expand-environment=no`.

### Mode, chosen once per member at `up`

- `up` sets `containment=scope` when `timeout 3 systemctl --user show-environment` succeeds, outside the lock;
  otherwise `containment=group`. `HERDR_TEAM_NO_SCOPE=1` forces `group`, for the self-test only.
- The member record gains `containment` and, in scope mode, `scope`. `up`'s JSON reply gains `containment`.
- The scope name is `herdr-team-<task>-<gen>-<member>.scope`. `gen` is 16 random hex digits, so the name is unique;
  `task` and the member name already match `[A-Za-z0-9_-]`, which systemd accepts.
- `up` writes the name to `$ctl/scope` (for `stop_member`) and bakes it into the launch script as a variable, next
  to `ctl` and `scale`. The launcher never reads the file, so a concurrent `teardown` removing `$ctl` cannot race it.

### What the scope wraps: only the member command

The launcher and its watchdog stay outside the scope, in the pane's cgroup. In scope mode the member line becomes:

```bash
set -m
systemd-run --user --scope --quiet --collect --expand-environment=no --unit="$scope" \
  -p TimeoutStopSec="$stop_secs" -- bash -c '…writes pgid, exports HERDR_TEAM_MEMBER, exec "$@"' \
  "$ctl" "${argv[@]}" 2>"$ctl/stderr" || code=$?
```

Because systemd-run execs in place, the member keeps the PID, process group, session and terminal that `set -m`
gave it, so `ctrl+c` in the pane and `finish`'s graceful quit reach it as today. The `pgid` the inner `bash` records
is still right for the group fallback.

- `stop_secs` is `5 × HERDR_TEAM_TIME_SCALE`, rounded up, at least 1: TERM, then KILL after `stop_secs`.
- `--quiet` keeps "Running as unit" out of `$ctl/stderr`; `--collect` unloads the unit even when it ends failed.
- If `systemd-run` cannot create the scope, the member never starts and `up` fails with the launcher's exit status.
  There is no silent fallback to group mode.

### `stop_scope`

Defined twice, in `herdr-team.sh` and in the launch heredoc (the launcher is a separate script):

```bash
stop_scope() { # unit: stop it; fails only if it is still active afterwards
  timeout "$((stop_secs + 5))" systemctl --user stop -- "$1" >/dev/null 2>&1 || :
  ! systemctl --user is-active --quiet -- "$1" 2>/dev/null
}
```

A unit already gone (`--collect` unloaded it) counts as stopped. In `herdr-team.sh` it runs only for a name that
matches `^herdr-team-[A-Za-z0-9_-]+\.scope$`. Nothing here is fatal under `errexit`: callers test its status.

### Where the scope is stopped

| Point | Today | Scope mode |
| --- | --- | --- |
| Member's main process exits (crash included) | nothing until teardown | launcher writes `status`, calls `stop_scope`, then writes `exit` |
| Launcher gets HUP, TERM or INT (pane closed) | launcher dies, children stay | an `EXIT` trap in the launcher calls `stop_scope` |
| Watchdog (lead gone, or role maximum) | `kill_group TERM`, 5 s, `kill_group KILL` | `stop_scope`, then the same `kill_group` pair |
| `finish`, `down`, `sweep` (through `stop_member`) | group, then marked pids | `stop_scope`, then the group-and-marker pass |
| Launcher killed with KILL | next `sweep`, once the whole task is dead | next `sweep`, per member (below) |

- **Exit record after the stop.** `ask`, `up` and `finish` act as soon as `$ctl/exit` exists; `ask` then
  fingerprints the worktree. Writing `exit` only after `stop_scope` means no stray process can still change the
  worktree at that point. `status` is written first, so it holds the member's last lines, not stop noise.
- **Watchdog fallback.** After `stop_scope` the watchdog still sends `kill_group TERM`, waits, and sends
  `kill_group KILL`, so a wedged manager still ends the member's own group.
- **Per-member sweep.** Today `sweep` skips a task while any member is live. It now also walks the members of a
  live task: for each member whose launcher is dead (recorded pid and start no longer match) and that has a
  `scope`, it calls `stop_scope`. The record stays; the lead's `down` or `finish` removes it as today.
- **A stop that fails keeps the handle.** If `stop_scope` fails in `teardown`, the member's record (marked
  `cancelled`) and `$ctl` are kept, `herdr-team` prints `herdr-team: scope <unit> did not stop`, and `teardown`
  returns nonzero after closing the pane. The next `sweep` finds a dead launcher and retries.

### Packaging

`systemd` joins `runtimeInputs` of the `herdr-team` package in `home/development/agent-run.nix`. The launcher
inherits that `PATH`, so it finds `systemd-run` and `systemctl` without `/run/current-system`.

### Test isolation

The test exports its own `XDG_RUNTIME_DIR`, where `systemctl --user` finds no bus, so the scope cases would always
skip. `herdr-team.sh` reads `rt=${HERDR_TEAM_RUNTIME_DIR:-$XDG_RUNTIME_DIR/herdr-team}`. The test sets
`HERDR_TEAM_RUNTIME_DIR` for its state and leaves `XDG_RUNTIME_DIR` alone when it runs the scope cases.

### Bus guard

Not changed; no exemption. The guard reads only the command text of Claude's own Bash calls, and
`herdr-team down` or `finish` does not contain `systemctl`. An agent typing `systemctl --user stop herdr-team-…`
itself still needs the announcement.

## Alternatives rejected

- **Wrap the whole launcher in the scope.** The stop would end the launcher before it records the exit, and the
  watchdog would sit inside the cgroup it stops.
- **A transient service** (`systemd-run --user` without `--scope`). It runs under the user manager, away from the
  pane's terminal, so the member loses its visible pane and `ctrl+c`.
- **`systemctl --user kill` with our own TERM → wait → KILL loop.** It duplicates `stop` with `TimeoutStopSec`.
- **Codex `shell_environment_policy` to keep the marker, plus a scan of all the user's processes.** Fixes the
  environment but not the new session, and misses anything that clears its environment.
- **Drop group mode.** The Nix build sandbox has no user systemd, so the packaged self-test could not run.
- **Fall back to group mode when `systemd-run` fails at launch.** That hides a broken user manager and quietly
  weakens containment.

## Risks

- **A wedged user manager (p620, razer).** Every `systemctl` call is under `timeout`; `stop_member` and the
  watchdog still run the group pass; a failed stop keeps the record for the next `sweep`. A launch on a wedged
  manager stalls until `up`'s 60 s wait fails it.
- **The exit record now waits for the stop**, up to `stop_secs` when a stray process ignores TERM. `finish` already
  waits up to 10 s for the exit record.
- **A launcher killed before `systemd-run` execs** never wrote `pgid`; that gap predates this change, and closing
  the pane ends such a launcher.
- **The Nix build runs the suite in group mode only.** Scope mode is tested only on a host with user systemd.
- **p510** picks this up at its next deploy, which needs the owner's OK.

## Verification

- `shellcheck --exclude=SC2016 home/development/herdr-team.sh` is clean.
- `herdr-team-test.sh`, existing cases: pass with `HERDR_TEAM_NO_SCOPE=1`, and on p620 without it.
- New cases, skipped when `timeout 3 systemctl --user show-environment` fails:
  - A member that starts `setsid bash -c 'trap "" TERM; exec sleep 600' &` and exits nonzero: once `$ctl/exit`
    exists, the sleep is gone, and it was gone within `stop_secs + 2` s of the member's exit.
  - The same after the watchdog fires, after `down --force`, and after `finish`.
  - Launcher killed with KILL while another member of the task is live: the next `up` of a third member stops the
    dead member's scope.
  - Afterwards the unit is not loaded; the state file had `containment: "scope"` and the `scope` name.
- New: with `HERDR_TEAM_NO_SCOPE=1`, `up` reports `containment: "group"`.
- 20 local runs in a row pass on p620.
- Both hosts build (`just test-host p620`; razer through p620); the build runs the suite in group mode.
- Live check on p620 after deploy, in a herdr team tab with a Codex member:
  - the member runs inside `herdr-team-<task>-<gen>-review.scope`;
  - `ctrl+c` typed in the pane reaches Codex as today, and `finish` quits it gracefully;
  - a Codex tool command `sleep 600 &`, then `down --force`: the `sleep` and the unit are gone.
