---
status: approved
issue: 2835
spec: spec/2026-11-10-2835-herdr-team-systemd-scope.md
coders:
  1: codex # small tricky logic across stop_member, teardown and sweep
  2: codex # the launcher's exit ordering, trap and watchdog are subtle
  3: coder # test cases follow the suite's existing helpers
  4: coder # docs
reviewers:
  - codex # second read of the stop and race logic
  - agy # independent read; it found the test-isolation and exit-order traps in the spec
---

# Plan: contain each herdr-team member in a systemd scope

Branch `fix/2835-herdr-team-systemd-scope`, worktree `~/.config/nixos-2835`. Lands after #2829, before #2828.

## Approved decisions

1. Each member runs inside its own transient user scope, `herdr-team-<task>-<gen>-<member>.scope`. Only the member
   command is inside; the launcher and watchdog stay in the pane's cgroup.
2. Mode is chosen once at `up`: `containment=scope` when `timeout 3 systemctl --user show-environment` succeeds
   (run outside the lock), else `group`. `HERDR_TEAM_NO_SCOPE=1` forces `group` (self-test only). The member record
   gains `containment` and, in scope mode, `scope`; `up`'s JSON reply gains `containment`.
3. The launch line in scope mode is:

   ```bash
   systemd-run --user --scope --quiet --collect --expand-environment=no --unit="$scope" \
     -p TimeoutStopSec="$stop_secs" -- bash -c '…' "$ctl" "${argv[@]}"
   ```

   `--expand-environment=no` is mandatory: systemd 262 otherwise turns `$$` into `$`. systemd-run execs in place, so
   PID, process group, session and terminal are unchanged (probed on p620), and the recorded `pgid` stays right.
4. `stop_secs` = `5 × HERDR_TEAM_TIME_SCALE`, rounded up, at least 1.
5. `stop_scope <unit>`, defined in `herdr-team.sh` and again in the launch heredoc:

   ```bash
   stop_scope() { # unit: stop it; fails only if it is still active afterwards
     timeout "$((stop_secs + 5))" systemctl --user stop -- "$1" >/dev/null 2>&1 || :
     ! systemctl --user is-active --quiet -- "$1" 2>/dev/null
   }
   ```

   In `herdr-team.sh` it runs only on a name matching `^herdr-team-[A-Za-z0-9_-]+\.scope$`.
6. `up` writes the name to `$ctl/scope` and bakes it into the launch script as `scope=…`; the launcher never reads
   the file.
7. Stop points: the launcher writes `status`, calls `stop_scope`, then writes `exit`; an `EXIT` trap in the launcher
   calls `stop_scope` on HUP, TERM or INT; the watchdog calls `stop_scope`, then keeps its `kill_group TERM`, wait,
   `kill_group KILL`; `stop_member` calls `stop_scope`, then the #2818 group-and-marker pass.
8. `sweep` also walks live tasks: for each member whose launcher is dead and that has a `scope`, it calls
   `stop_scope`, leaving the record.
9. If `stop_scope` fails in `teardown`, the record (marked `cancelled`) and `$ctl` are kept, it prints
   `herdr-team: scope <unit> did not stop`, closes the pane and returns nonzero. The next `sweep` retries. The
   same holds in `sweep`'s stale-task path: a member whose `stop_member` fails keeps its record and `$ctl`, and the
   state file stays. `down` and `finish` go on with the other members and their JSON reply, and add
   `"scope_stop_failed": [<member>…]`; `down` then exits 1.
10. No silent fallback: if `systemd-run` fails, the member never starts and `up` fails.
11. `rt=${HERDR_TEAM_RUNTIME_DIR:-${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/herdr-team}`, so the test can isolate
    its state and keep the real `XDG_RUNTIME_DIR` for `systemctl --user`.
12. `systemd` joins the `herdr-team` package's `runtimeInputs`.
13. The bus guard is not changed; no exemption.

## Steps

1. **`herdr-team.sh` core + packaging.** Line numbers are on main `d990ae4ce`; search by function name.
   - `:18-20`: add `stop_secs` after `scale` (decision 4) and the `rt` override (decision 11); add `stop_scope`
     (decision 5) next to `stop_member`. Document `HERDR_TEAM_RUNTIME_DIR` and `HERDR_TEAM_NO_SCOPE` in the comment
     at `:7`.
   - `up` (`:291`): before the `lock` near `:332`, set `containment` (decision 2). After `ctl=$rt/$gen/$role`
     (`:356`), set `scope`, write `$ctl/scope` in scope mode, and add `containment`/`scope` to `rec` (`:373`). Add
     `containment` to the final reply (`:489`).
   - `stop_member` (`:229`): read `$1/scope` and call `stop_scope` first, keeping its status in `rc` (0 when there is
     no `scope` file, as in group mode). The group-and-marker pass keeps its signalling exactly, but each of its
     `return 0` (`:231`, `:232`, `:236`, `:242`, `:245`, `:263`) becomes `return "$rc"`, and it ends `return "$rc"`.
   - `teardown` (`:268`): decision 9. `stop_member` failing must not abort under `errexit`
     (`if ! stop_member …; then`).
   - `down` (`:865`) and `finish` (`:915`): call `teardown` as `if ! teardown …; then failed+=("$m"); fi`, and report
     them (decision 9).
   - `sweep` (`:190`): the stale-task path follows decision 9 (`if ! stop_member "$ctl"; then` keep that member and
     the file). Decision 8 for live tasks, using `alive` on the recorded `pid`/`start`; skip members still starting
     up (no `pid`); call it as `stop_scope "$s" || :`.
   - `home/development/agent-run.nix:21`: add `systemd` to `runtimeInputs` (decision 12).
   → verify: `shellcheck --exclude=SC2016 home/development/herdr-team.sh`; the existing suite passes (command under
   Tests).
   Traps: `writeShellApplication` adds `errexit`, `nounset`, `pipefail`; every `systemctl` call is guarded. Prose
   containing `systemctl … stop` in a Bash command trips the bus guard: put it in a file.

2. **The launch heredoc** (`:411-450`).
   - Print `scope`, `containment` and `stop_secs` into the script with the other `printf '%q'` variables.
   - Define `stop_scope` there (decision 5), a no-op when `containment` is `group`.
   - In scope mode, the member line at `:444` becomes the `systemd-run` line of decision 3, wrapping the existing
     `bash -c` unchanged. Group mode keeps today's line.
   - After the member returns: `kill "$wd" 2>/dev/null`, write `status`, call `stop_scope "$scope" || :`, then
     `trap - EXIT`, then write `exit`, so a normal exit stops the scope once.
   - `trap 'stop_scope "$scope" || :' EXIT` set before `set -m`; HUP, TERM and INT exit through it
     (`trap 'exit 129' HUP` etc.).
   - Watchdog (`:430-439`): `stop_scope "$scope" || :` before the existing `kill_group` sequence, which stays.
   → verify: as step 1. Until step 3 the suite runs in group mode only (it sets its own `XDG_RUNTIME_DIR`), so steps
   1–2 are proven in scope mode only at step 3.
   Traps: the launch script is plain `bash` without `errexit`. The heredoc is quoted (`<<'LAUNCH'`); variables
   come only from the `printf '%q'` header. The inner `bash -c` string must not change, or the `pgid` record and
   marker break.

3. **Tests** (`home/development/herdr-team-test.sh`).
   - `:21-26`: drop `XDG_RUNTIME_DIR` from the `export` at `:21`, export
     `HERDR_TEAM_RUNTIME_DIR="$tmp/runtime/herdr-team"`, set `rt` from it, and make `:22` create
     `$HERDR_TEAM_RUNTIME_DIR` instead of `$XDG_RUNTIME_DIR` (unset in the Nix sandbox, `nounset` is on). The line-4
     loop unsets `HERDR_*`, so set test vars after it.
   - The #2818 orphan cases (`:953-989`, "stopping by marker") assert that `sleep 62.3` outlives the member, which
     scope mode prevents: run their `up` calls with `HERDR_TEAM_NO_SCOPE=1`.
   - A second argument `group` exports `HERDR_TEAM_NO_SCOPE=1` for the whole run. Without it, the existing cases run
     in the host's mode.
   - One helper stops every unit named in `$rt/*/*/scope` (only units this run made); `cleanup` and `reset` (`:150`)
     call it before they delete `$rt`. Both also `pkill -f 'sleep 64.7'`.
   - New cases, skipped (`ok skip …`) when `timeout 3 systemctl --user show-environment` fails or `group` was given:
     - fake member starts `setsid bash -c 'trap "" TERM; exec sleep 64.7' &` then exits 3: once `$ctl/exit`
       exists the sleep is gone, within `stop_secs + 2` s of the member's exit;
     - the same after the watchdog fires, after `down --force`, and after `finish`;
     - launcher killed with KILL while another member is live: the next `up` of a third member stops its scope;
     - afterwards `systemctl --user show -P LoadState <unit>` prints `not-found` (`--collect` unloaded it); the
       state file had
       `containment: "scope"` and the `scope` name.
   - New: with `group`, `up` reports `containment: "group"`.
   → verify: the suite passes with and without `group`; 20 runs in a row without `group` on p620.
   Traps: a fixed `sleep` in a test flakes; use `wait_for`/`wait_until`. Pick a sleep duration no other case uses.

4. **Docs** (`docs/applications/herdr.md`, herdr-team section from `:192`): the two containment modes, what group
   mode misses, the scope name, and `systemctl --user status herdr-team-*` for a check. Nav is unchanged.
   → verify: `markdownlint-cli2 docs/applications/herdr.md`.

5. **Ship (Claude).** `just test-host p620`; razer through p620. Fresh Opus review on `git diff main` with this
   plan, plus Codex and agy (`reviewers:`). PR linking all three files. Announce on `#agents:freundcloud.org.uk`,
   deploy p620, then `just deploy-via-p620 razer`. Live check on p620 (Tests). p510 is not built or deployed.

## Tests

```bash
t=$(mktemp)
printf 'set -euo pipefail\nagy_member=false\nsink_path=%s\n' "$(command -v herdr-team-sink)" >"$t"
cat home/development/herdr-team.sh >>"$t"; chmod +x "$t"
bash home/development/herdr-team-test.sh "$t" </dev/null; echo "scope exit=$?"
bash home/development/herdr-team-test.sh "$t" group </dev/null; echo "group exit=$?"
```

Both exit 0. The host builds run the suite in group mode (no user systemd in the sandbox).

Live check on p620 after deploy, in a herdr team tab with a Codex member:

- `systemctl --user status 'herdr-team-*'` shows the member's scope;
- `ctrl+c` in the pane reaches Codex as today, and `finish` quits it gracefully;
- a Codex tool command `sleep 600 &`, then `down --force`: the `sleep` and the unit are gone.

## Rollback

Revert the merge commit and redeploy p620 and razer. No state migrates: the new record fields and `$ctl/scope` are
ignored by the old script, which does not stop a scope. Before the revert, with no team running, stop any leftover
unit by hand (`systemctl --user list-units 'herdr-team-*'`), after the bus announcement.

## Deviations

- Step 1 (coder; Codex's coder guard refused the scope-stop code, so the coder took it):
  - `sweep`'s stale-task path deletes each member that stopped cleanly from the record at once, so only the members
    whose scope did not stop remain in the kept state file.
  - `finish` reports a failed stop in `scope_stop_failed` but keeps its exit status (its `ok` reflects the diff
    checks); only `down` exits 1 on a failed stop.
- Step 2 (coder, same reason): the unchanged inner `bash -c` string is held in a `member='…'` variable that both the
  scope and group branches pass to `bash -c "$member"`, instead of being written out twice.
- Step 3 (coder): the killed-launcher case brings up the third member as a `t2` review in another task, because
  `agy-implement` is refused in the suite. It waits for the child to go with `wait_until` and does not assert the
  time bound; the member-exit case does (exit record within 3 s of the member's exit at
  `HERDR_TEAM_TIME_SCALE=0.05`). 20 runs in a row passed.
- Review fixes (Opus, Codex):
  - `stop_scope` succeeds only when `systemctl show -p ActiveState` reads `inactive` or `failed`; a `deactivating`
    unit or an unreachable manager counts as a failed stop.
  - Decision 7's launcher traps are removed. Bash runs a trap only after the foreground member exits, so the traps
    could not stop a running member, and on a hangup they kept the launcher alive, which hid a leftover member from
    `sweep`. A hung-up launcher now dies as before, and `sweep` stops its scope.
  - `sweep`'s second loop skips tasks with no live member, so a kept scope is not stopped twice under the lock.
  - Reads of `scope` and `pgid` hide a missing file's error.
  - New case: a scope systemd reports as still `deactivating` makes `down` exit 1 with `scope_stop_failed`, keeps
    the record, and the next `down` removes it.
