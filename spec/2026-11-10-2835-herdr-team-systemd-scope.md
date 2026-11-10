---
status: draft
issue: 2835
intent: intent/2026-11-10-2835-herdr-team-systemd-scope.md
---

# Spec: contain each herdr-team member in a systemd scope

## Design

All changes are in `home/development/herdr-team.sh` (the launcher heredoc, `stop_member`, `up`), its test and the docs.

### Mode, chosen once per member at `up`

- `up` sets `containment=scope` when `systemctl --user show-environment` succeeds, otherwise `containment=group`.
  `HERDR_TEAM_NO_SCOPE=1` forces `group`, for the self-test only (like `HERDR_TEAM_TIME_SCALE`).
- The member record gains `containment` and, in scope mode, `scope`. `up`'s JSON reply gains `containment`.
- The scope name is `herdr-team-<task>-<gen>-<member>.scope`. `gen` is 16 random hex digits, so the name is unique;
  `task` and the member name already match `[A-Za-z0-9_-]`, which systemd accepts in unit names.
- `up` writes the name to `$ctl/scope` before typing the launch line. `$ctl` sits under `$XDG_RUNTIME_DIR/herdr-team`
  (mode 0700), so only this user can plant a name there.

### What the scope wraps: only the member command

The launcher (and its watchdog) stay outside the scope, in the pane's own cgroup. Only the member command moves in.
The launcher's member line becomes, in scope mode:

```bash
set -m
systemd-run --user --scope --quiet --collect --unit="$scope" -p TimeoutStopSec="$stop_secs" -- \
  bash -c '…writes pgid, exports HERDR_TEAM_MEMBER, exec "$@"' "$ctl" "${argv[@]}" 2>"$ctl/stderr" || code=$?
```

`systemd-run --scope` registers the scope for its own PID and then `exec`s the command, so the member keeps the PID,
process group, session and terminal that `set -m` gave it. The probe on p620 showed this: the scope was named
`run-p<pid>` after the caller's own PID. That answers the intent's first open question: `ctrl+c` in the pane and
`finish`'s graceful quit still reach the member's foreground group. The live pane check in Verification proves it.

- `stop_secs` is `5 × HERDR_TEAM_TIME_SCALE`, at least 1. `systemctl --user stop` then sends TERM to every process
  in the scope, waits `stop_secs`, and sends KILL. That gives the 5 s bound instead of systemd's default 90 s.
- `--quiet` drops the "Running as unit" line, so `$ctl/stderr` holds only the member's output.
- `--collect` removes the unit even when it ends failed, so names never linger.
- If `systemd-run` cannot create the scope, the member never starts: the inner `bash` does not run, `$ctl/pgid` is
  never written, and `up` fails with the launcher's exit status. There is no silent fallback to group mode.

### Where the scope is stopped

One helper, `stop_scope <ctl>`, runs `systemctl --user stop -- "$(<"$ctl/scope")"` when `$ctl/scope` exists and
matches `^herdr-team-[A-Za-z0-9_-]+\.scope$`. A unit that is already gone is not an error.

| Point | Today | Scope mode |
| --- | --- | --- |
| Member's main process exits (crash included) | nothing until teardown | launcher writes `status` and `exit` first, then calls `stop_scope` |
| Watchdog (lead gone, or role maximum) | `kill_group TERM`, 5 s, `kill_group KILL` | `stop_scope` |
| `finish`, `down`, `sweep` (through `stop_member`) | group, then marked pids | `stop_scope`, then the group-and-marker path as today |
| Launcher killed outright | caught by the next `sweep` | the same; `sweep` calls `stop_member`, which stops the scope |

- `stop_member` calls `stop_scope` first and keeps the #2818 group-and-marker stop after it. In scope mode that
  second pass finds nothing; in group mode it is the only stop, unchanged.
- The launcher writes `status` and `exit` before it stops the scope, so a slow stop never delays the exit record
  that `finish` and `rm_retry` wait for, and `status` holds the member's last lines, not stop noise.
- The watchdog's stop happens in the launcher's own subshell, outside the scope, so stopping the scope never kills
  the launcher.

### Packaging

`systemd` joins `runtimeInputs` of the `herdr-team` package in `home/development/agent-run.nix`. The launcher
inherits that `PATH`, so it finds `systemd-run` and `systemctl` without relying on `/run/current-system`.

### Bus guard

Not changed, and no exemption is added. The guard inspects only the command text of Claude's own Bash calls, and
`herdr-team down` or `finish` does not contain `systemctl`. A direct `systemctl --user stop herdr-team-…` typed by an
agent still needs the announcement.

## Alternatives rejected

- **Wrap the whole launcher in the scope.** The scope stop would then also end the launcher before it records the
  exit, and the watchdog would sit inside the cgroup it stops.
- **`systemd-run --user` as a transient service** instead of a scope. A service runs under the user manager, away
  from the pane's terminal, so the member would lose its visible pane and `ctrl+c`.
- **`systemctl --user kill` with our own TERM → wait → KILL loop.** It duplicates what `stop` already does with
  `TimeoutStopSec`, and leaves the unit loaded.
- **Codex `shell_environment_policy` to keep the marker, plus a scan of all the user's processes.** It fixes the
  environment but not the new session, costs a scan of every process, and still misses anything that clears its
  environment.
- **Drop group mode.** The Nix build sandbox has no user systemd, so the packaged self-test could not run.
- **Fall back to group mode when `systemd-run` fails at launch.** That would hide a broken user manager and quietly
  weaken containment; `up` reports the failure instead.

## Risks

- **User manager present but its bus slow or wedged (p620, razer).** `systemctl --user stop` could hang. Mitigation:
  `stop_scope` runs it under `timeout $((stop_secs + 5))`; the group-and-marker pass still runs after it.
- **`systemd-run` waits for the scope job.** A wedged manager would stall the launch; `up` already fails after its
  60 s wait for herdr to report the agent.
- **Leftover processes that ignore TERM** get KILL after `stop_secs`, as in #2818.
- **Self-test only covers group mode in the Nix build.** Scope mode is tested only when the suite runs on a host
  with user systemd (see Verification).
- **p510** picks this up at its next deploy, which needs the owner's OK.

## Verification

- `shellcheck --exclude=SC2016 home/development/herdr-team.sh` is clean.
- `herdr-team-test.sh`:
  - The existing cases pass with `HERDR_TEAM_NO_SCOPE=1` and, on a host with user systemd, without it.
  - New, skipped when `systemctl --user show-environment` fails: a member that starts `setsid sleep 600 &` and then
    exits nonzero leaves no `sleep` once the launcher exits; the same after the watchdog fires; the same after
    `down --force`; the scope unit no longer exists afterwards; `up` reports `containment: "scope"`.
  - New: with `HERDR_TEAM_NO_SCOPE=1`, `up` reports `containment: "group"`.
  - 20 local runs in a row pass.
- Both hosts build (`just test-host p620`, and razer through p620); the build runs the packaged suite in group mode.
- Live check on p620 after deploy, in a herdr team tab with a Codex member:
  - The member runs inside `herdr-team-<task>-<gen>-review.scope` (`systemctl --user status`).
  - `ctrl+c` typed in the pane reaches Codex as today, and `finish` quits it gracefully.
  - A Codex tool command `sleep 600 &`, then `down --force`: the `sleep` is gone and the unit is gone.
