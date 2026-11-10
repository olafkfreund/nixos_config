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

**A per-member marker gives identity.** The launcher (herdr-team.sh:356) passes `HERDR_TEAM_MEMBER=<ctl>` to the
member's `exec`, and `HERDR_TEAM_MEMBER` is added to `agent_env_names` in `agent-env.sh`, so `agent-env`'s
allowlist keeps it. `<ctl>` is unique per member (random generation), and every descendant inherits it.

A pgid alone cannot prove identity. Once our group has fully emptied, the kernel may give that id to an
unrelated group, and its members pass any pgid-plus-start-time check (both reviewers showed this). The marker
closes that hole: an unrelated process does not carry our `ctl` path.

`stop_member` (herdr-team.sh:166) drops the launcher-alive guard. The `pgid` file sits in our own 0700 `ctl`
dir, written before the `exec`, so it does not depend on the launcher. Then:

- **Leader alive with the recorded start time:** same as today. The live leader pins the pgid, so the group
  signal (`kill -TERM -<pgid>`, wait, `kill -KILL -<pgid>`, wait) is safe.
- **Otherwise (leader gone, or the pid now runs with a different start time):** never signal the group id.
  - A new helper `member_pids <pgid> <ctl>` lists our processes. A pid is ours when one read of
    `/proc/<pid>/stat` shows pgrp (field 3 after the closing parenthesis) equal to `<pgid>`, and `/proc/<pid>/environ` contains
    `HERDR_TEAM_MEMBER=<ctl>` as a whole NUL-separated entry.
  - It prints `pid start` pairs, with start compared as a number.
  - TERM each pair after re-checking it with `alive pid start`.
  - Wait up to 5 s. Then KILL only the same pairs that `alive` still matches. Pids found later are not
    signalled; they are left for the next pass, again verified by the marker.
- **Residual window:** a verified pid could exit and be reused in the microseconds between the check and the
  `kill`. That needs the pid space (`pid_max` 4194304) to wrap in that window. Today's `alive` checks make the
  same assumption.

**A member that strips its environment survives.** A tool that clears the environment for its child
commands produces unmarked processes, and those are never signalled: the safe direction. The verification
below checks that Codex shell commands keep the marker.

**`sweep`** (herdr-team.sh:146) calls `stop_member` for each member before `rm_dirs`. That also stops a stale
task's leftovers, which today are lost for good. `sweep` runs under the lock inside `up`, so a stale task can
delay that `up` by up to 10 s per member.

### 2. Tests wait for state, not time

Four fixed sleeps order concurrent events in `home/development/herdr-team-test.sh`:

| Line | Waits for | Replace with |
| ---- | --------- | ------------ |
| :350 `sleep 0.5` | the request to be delivered | a poll until `$TEST_STATE/prompts` has the pointer line (the fake herdr logs it, test:64) |
| :413 `sleep 0.4` | the request to be sent | the same `wait_for` |
| :484 `sleep 0.2` | the killed owner to be gone | `wait "$owner"`, which reaps it; a `kill -0` poll would still see the zombie |
| :609 `sleep 0.3` | the grandchild to start | a bounded poll on `pgrep -g "$pgid" -x sleep` (`-f` would match the parent `bash -c` before its `trap "" TERM` runs) |

For the revision test, waiting for `req/1.md` is enough: `ask` takes the revision fingerprint (herdr-team.sh:480)
before it writes `req/<n>.md` (:494). The test's unused `printf 'x' >"$TEST_STATE/reply"` and `pokes` lines
(:414–415) go, so the fake herdr cannot race to write a second turn.

A new helper `wait_until <cmd…>` polls a command the same way `wait_for` polls a path: 100 × 0.05 s.

The `sleep 0.2` after `wait_for …/exit` (:345) is removed: the launcher moves `status` into place before `exit`
(herdr-team.sh:359–360).

### 3. Keep the exchange

The archive lives in `$rt/archive/<gen>/`. Every directory in it (`archive`, `<gen>`, `<member>`) is made with
`mkdir -m 700`. The files are plain copies.

- **`keep_answers <gen> <member> <work>`** runs under the lock. `teardown` and `sweep` call it before
  `rm_dirs`.
  - It returns quietly if `<work>` is empty or has no `ans/`.
  - A member name repeats within a generation: the next `up … implement --step k` reuses `implement`. So the
    target is the first free name of `<member>`, `<member>.2`, … .
  - It copies `<work>/ans/` there.
  - It appends `<work>/ans/ → <archive dir>/` to `archive/<gen>/paths`.
  - The live log is never rewritten.
- **`rm_gen`** (under the lock) copies `$rt/<gen>/conversation.jsonl`, if present, to
  `archive/<gen>/conversation.jsonl`. It rewrites each `answer` path with the `paths` map in one `jq` pass, then
  deletes `$rt/<gen>`.
- **`emit`** takes the lock for its append. That closes the lost-append race with `rm_gen`. If `$rt/<gen>` is
  already gone (a forced `down` removed the last member mid-`converse`), it appends to
  `archive/<gen>/conversation.jsonl` instead, so the final `cancelled` hop is kept.
- **Copy failures** are warned about on stderr and never block teardown.
- **Pruning:** none, the intent's default.
- **Docs:** `docs/applications/herdr.md` says where the archive is.

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

- **Cgroups or `systemd-run --scope` per member.** They give exact containment, but change how members launch,
  and they need user systemd from inside herdr panes.
- **Identity by pgid plus start time alone.** Both reviewers showed it fails once the group empties and the id
  is reused.
- **Keeping a sleeper in the group** to pin the pgid. It works, but it adds a process per member, which the
  launcher must also reap. The marker gives identity without that.
- **pidfd signalling.** It is race-free per pid, but bash has no pidfd. A Python helper would add a runtime
  dependency for a window that needs a pid wrap.
- **Rewriting the live `conversation.jsonl` at each member teardown.** It races with `emit` (Codex, agy). One
  rewrite at `rm_gen` with a path map avoids it.
- **Moving `<work>/ans` instead of copying it.** `rm_dirs` retries because the launcher writes late. A copy
  keeps that path unchanged.
- **Archiving in the repo or `~/.local/state`.** The intent requires the runtime dir.
- **Pruning to N generations.** It is not wanted (intent default), and can be added later in one line.

## Risks

- **A process that drops `HERDR_TEAM_MEMBER`, or leaves the group** (`setsid`/`setpgid`), is not stopped.
  Neither is ever wrongly signalled. The docs say so.
- **The residual pid-wrap window** described in section 1.
- **The `sweep` delay:** up to 10 s per stale member, under the lock.
- **`emit` under the lock** adds one lock round trip per hop, which is cheap next to a model turn.
- **Hosts:** p620 and razer through Home Manager. Only herdr-team is affected. Rollback is a revert.

## Verification

- `bash home/development/herdr-team-test.sh` passes, with new cases:
  - **Orphan after exit:** the member starts a `sleep` in its group and exits, then the launcher exits. `down`
    leaves no process in the group. The same holds for `finish implement`.
  - **Sweep:** a state file whose launcher is dead while a group survivor still runs. The next `up` kills the
    survivor and logs the removed task.
  - **Reuse guard:** the existing `pid-reuse` decoy case still passes. A new case: a leaderless group whose
    pgid matches the recorded one but whose processes lack the marker is not signalled.
  - **Archive:** after `converse` then `finish implement` then `down`, these exist, under 0700 directories:
    - `archive/<gen>/review/1.md`;
    - `archive/<gen>/implement/…`;
    - `archive/<gen>/conversation.jsonl`, whose `answer` paths all exist.
  - A second `implement` in the same gen archives to `implement.2/`.
  - A forced `down` during `converse` keeps the final `cancelled` hop in the archived log.
  - **Keys:** the environment checks see `ANTHROPIC_API_KEY_FILE` stripped.
- The test passes 20 times in a row (loop), including under `nice -n 19` with a parallel `nix build` for load.
- `shellcheck` is clean, and `just check-syntax` / `just test-host p620` and `razer` build.
- Live on p620 after the deploy:
  1. `herdr-team up … review`, then `up … implement`.
  2. The implementer runs `sleep 600 &` and quits. `/proc/<sleep pid>/environ` carries `HERDR_TEAM_MEMBER`,
     which shows that Codex's shell commands keep it.
  3. `finish`, then check `pgrep -f 'sleep 600'` is empty.
  4. `down`, then read `archive/<gen>/conversation.jsonl`.
