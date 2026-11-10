---
status: draft
issue: 2818
intent: intent/2026-11-09-2818-herdr-team-followups.md
---

# Spec: herdr-team follow-ups

## Design

All changes are in `home/development/herdr-team.sh` and its test, plus the key lists. Nothing changes how
members launch, talk or finish.

### 1. Stop the whole group, even after the member and launcher exited

`stop_member` (herdr-team.sh:166) has three guards. Today all three must pass:

1. The launcher (`pid`/`start` in the state file) is alive.
2. The `pgid` file exists.
3. The recorded leader (`pgid`/`pstart`) is alive.

The launcher check goes. The pgid file sits in our own 0700 `ctl` dir, and the launcher wrote it before the
`exec`, so it does not depend on the launcher still running. Then:

- **Leader alive with the recorded start time:** same as today. `kill -TERM -<pgid>`, wait, then
  `kill -KILL -<pgid>`, wait.
- **Leader gone (`/proc/<pgid>` missing):**
  - The kernel does not reuse a pid while a process group with that id has members. So any process whose pgid
    is `<pgid>` survived from our group.
  - Signal those processes one by one, never the group id. Each pid comes from `pgrep -g <pgid>` and is
    signalled only if its `/proc/<pid>/stat` still shows pgid `<pgid>` and a start time at or after `pstart`.
  - This closes the one remaining race: the group empties and the id is reused by a new group leader between
    the listing and the kill.
  - TERM, wait, then KILL the stragglers.
- **Leader alive with a different start time:** the pid was reused. Signal nothing, as today.

The 5 s TERM wait and the 5 s KILL wait stay. A new helper `group_pids <pgid> <pstart>` prints the verified pids.
The leader-gone path is a loop over it.

`sweep` (herdr-team.sh:146) calls `stop_member` for each member before `rm_dirs`. That also kills a stale
task's leftover group, which today is lost for good. `sweep` runs under the lock inside `up`, so a stale group
can delay that `up` by up to 10 s. That is the price of not leaving the process behind.

### 2. Tests wait for state, not time

Four fixed sleeps order concurrent events in `home/development/herdr-team-test.sh`:

| Line | Waits for | Replace with |
| ---- | --------- | ------------ |
| :350 `sleep 0.5` | the request to be open | `wait_for "$(field t1 review work)/req/1.md"` |
| :413 `sleep 0.4` | the request to be sent | the same `wait_for` |
| :484 `sleep 0.2` | the killed owner to be gone | `wait "$owner"` or a bounded `kill -0` poll |
| :609 `sleep 0.3` | the grandchild to start | a bounded poll on `pgrep -g "$pgid" -f 'sleep 61.7'` |

`wait_for`'s use for the `req/1.md` cases is valid: `ask` takes the revision fingerprint (herdr-team.sh:480)
before it writes `req/<n>.md` (:494). So once the file exists, an edit is guaranteed to come after the snapshot.

A new helper `wait_until <cmd…>` polls a command the same way `wait_for` polls a path: 100 × 0.05 s.

The `sleep 0.2` after `wait_for …/exit` (around :346) gives the launcher time to write `status`. It becomes
`wait_for "$ctl/status"` if that file is written last, or else stays as it is. The plan checks which.

### 3. Keep the exchange

The archive root is `$rt/archive/<gen>/`, created at 0700. `$rt` is already 0700.

- **`keep_answers <gen> <member> <work>`:** called by `teardown` and by `sweep` before `rm_dirs`.
  - It copies `<work>/ans/` into `archive/<gen>/<member>/`.
  - A member name repeats within a generation: after `finish implement`, the next `up … implement --step k`
    reuses `implement`. So the first free name of `<member>`, `<member>.2`, `<member>.3` … is used.
  - It also rewrites that member's answer paths in the live `$rt/<gen>/conversation.jsonl` from `<work>/ans/` to
    the archive dir, so the log keeps pointing at files that exist. The rewrite is done with `jq` into a temp
    file, then `mv`, under the lock.
- **`rm_gen`:** before deleting `$rt/<gen>`, it copies `conversation.jsonl` (if present) to
  `archive/<gen>/conversation.jsonl`.
- **`status`/docs:** `docs/applications/herdr.md` says where the archive is, and that `down` no longer loses the
  log.
- **Copy failures** are warned about on stderr and do not block teardown. Not stopping a member because the copy
  failed would be worse.
- **Pruning:** none, the intent's default. The tmpfs is cleared at logout.

### 4. `ANTHROPIC_API_KEY_FILE`

Add it next to `ANTHROPIC_API_KEY` in every `env -u` list:

- `agent-env.sh`;
- `herdr-team.sh:281`;
- `codex-cli.nix:37`;
- `codex-cli/module.nix:97` and `:117`;
- `antigravity-config.nix:198` and `:209`;
- `modules/ai/antigravity-cli.nix:81`;
- the test's environment checks at `herdr-team-test.sh:93` and `:277`.

The plan re-greps for `ANTHROPIC_API_KEY` so no list is missed.

## Alternatives rejected

- **Cgroups or `systemd-run --scope` per member.** These give exact containment, but change how members launch,
  which the intent rules out. They also need user-systemd from inside herdr panes.
- **A group kill after a `/proc/<pgid>` absence check.** This is racy, because the id can be reused between the
  check and the kill. Per-pid verification removes that.
- **Keeping the group leader alive** (the launcher holding it) so the pgid stays pinned. That changes the launch
  path (`exec`).
- **Moving `<work>/ans` instead of copying it.** `rm_dirs`' retry loop exists because the launcher writes late. A
  copy keeps today's delete path unchanged.
- **Archiving into the repo or `~/.local/state`.** The intent requires the runtime dir.
- **Pruning to N generations.** It is not wanted (intent default), and can be added later in one line.

## Risks

- **A process that calls `setsid` or `setpgid`** leaves the group, and nothing here finds it. That is the same as
  today, and noted in the docs.
- **The `sweep` delay** above: `up` can wait up to 10 s per stale member, under the lock.
- **The `conversation.jsonl` rewrite** races with a running `converse` appending to it. The `converse` holds the
  task's conversation slot, and `teardown` of a member during a running `converse` already ends that
  conversation. The rewrite runs under the lock, and `emit` appends with `tee -a`. The plan checks that `emit`
  does not hold the file open across a teardown.
- **Archive size:** answers are small Markdown files on tmpfs.
- **Hosts:** p620 and razer through Home Manager. A broken script only affects herdr-team. Rollback is a revert.

## Verification

- `bash home/development/herdr-team-test.sh` passes, with new cases:
  - **Orphan after exit:** the member starts a `sleep` in its group and exits, then the launcher exits. `down`
    leaves no process in the group. The same holds for `finish implement`.
  - **Sweep:** a state file whose launcher is dead while a group survivor still runs. The next `up` kills the
    survivor and logs the removed task.
  - **Reuse guard:** the existing `pid-reuse` decoy case still passes. A decoy whose start time is before
    `pstart`, in a recorded pgid, is not signalled.
  - **Archive:** after `converse` then `finish implement` then `down`, these exist and are 0700:
    - `archive/<gen>/review/1.md`;
    - `archive/<gen>/implement/…`;
    - `archive/<gen>/conversation.jsonl`, whose `answer` paths all exist.
  - A second `implement` in the same gen archives to `implement.2/`.
  - **Keys:** the environment checks see `ANTHROPIC_API_KEY_FILE` stripped.
- The test passes 20 times in a row (loop), including under `nice -n 19` with a parallel `nix build` for load.
- `shellcheck` is clean, and `just check-syntax` / `just test-host p620` and `razer` build.
- Live on p620 after the deploy:
  1. `herdr-team up … review`, then `up … implement`.
  2. The implementer runs `sleep 600 &` and quits.
  3. `finish`, then check `pgrep -f 'sleep 600'` is empty.
  4. `down`, then read `archive/<gen>/conversation.jsonl`.
