---
status: approved
issue: 2829
spec: spec/2026-11-10-2829-herdr-team-finish-verify.md
coders:
  2: codex   # small, tricky control flow in finish (fingerprints, retries, failure order)
  3: coder   # test cases built on the existing fake herdr and agent
  4: coder   # docs and two skill notes
reviewers:
  - codex    # it found the retry and fingerprint holes in review
  - agy      # independent read of the failure ordering and concurrency
---

# Plan: `herdr-team finish --verify`

Self-contained: implementing this needs only this file and the code.

## Approved decisions

1. **The command:**

   ```text
   finish <task> implement|agy-implement [--verify CMD] [--retries N] [--verify-timeout S]
   ```

   `--retries` defaults to 1 and allows 0–3. `--verify-timeout` defaults to 900 and must be a positive integer;
   anything else is a usage error. Without `--verify`, behaviour is
   today's, plus `failures` and `verify: null` in the JSON.
2. `finish` gets the INT, TERM and HUP traps (`exit 130`, `143`, `129`). `release` removes the temp files.
3. **The guard, before every attempt.** Refuse with `verify_unsafe` if any of these is true:
   - the root is `~/.config/nixos` (compare with `realpath`);
   - the branch is `main`;
   - `HEAD` is detached, `origin/main` exists, and `HEAD == origin/main`.
4. **Fingerprints.**
   - `fp_impl` starts as `fingerprint` before attempt 1.
   - At each later attempt, if `fp_pre != fp_post` of the previous attempt, the implementer changed the tree, so
     `fp_impl=$fp_pre`.
   - `dirtied` is set when `fp_post != fp_pre`, and it sticks.
   - "empty diff" means `fp_impl == fp` when `--verify` ran.
5. **The check:**

   ```bash
   (cd "$root" && timeout "$vt" env -u <member key list> bash -c "$cmd") >"$out" 2>&1
   ```

   `$out` is a `mktemp` file under `$rt`.
6. **A retry:**
   - a request file holding the lead header, the command, the exit code, and the last 4 KB of output, trimmed
     UTF-8-safe like `cut_msg` with NULs dropped;
   - sent with `res=$(ask "$task" "$role" "$req" --timeout "${HERDR_TEAM_RETRY_TIMEOUT:-1800}")`;
   - if the outcome is not `ok`, set `retry_outcome` and stop the loop.
7. **`last`.**
   - Before the loop, `pre_last` is the member's `.last.outcome`.
   - After the loop, and before the graceful quit and teardown, `last` is read again.
   - The `last outcome is …` failure applies only when `pre_last` was not `ok` and no retry answered `ok`.
   - When a retry failed, `verify_retry_<o>` reports it instead.
8. **`failures`** collects every failure, in this order:
   1. `not_exited`;
   2. `tool exited N`;
   3. `verify_unsafe`;
   4. `verify_retry_<o>`, used instead of `last outcome is …` when a retry failed;
   5. `last outcome is …`;
   6. `HEAD moved`;
   7. `changes are staged`;
   8. `empty diff`;
   9. `verify_failed`.

   `reason` is `failures[0]`, or `""`.
9. **Concurrency.**
   - While the task's reservation is held, `ask`, `converse` and `down` (without `--force`) refuse with `busy`.
   - `finish`'s own retry `ask` is exempt only when the reservation's recorded pid **and** start time equal `$$`
     and `stat_field $$ 20`. In a `$( )` subshell, `$$` is still the reserving shell's pid.
   - The check runs under the state lock, at the point where `ask` sets `pending`. That closes the race with
     another caller that starts a `finish` in between.
10. **Output.**

    ```json
    {"verify": {"cmd": "...", "ok": true, "exit": 0, "attempts": 1, "dirtied": false, "retry_outcome": null, "tail": "..."}}
    ```

    `verify` is `null` without `--verify`.
11. **Skills.** `handoff` and `team` pass the plan step's check as `--verify`.

## Steps

1. **Lead: rebase on main after #2818 merges** (#2818 changes the same functions).
   - Command: `git rebase origin/main` in `~/.config/nixos-2829`.
   - Verify: `git log --oneline origin/main..` shows only this branch's artifacts.
   - Traps: never rebase in `~/.config/nixos`.
2. **`home/development/herdr-team.sh`: `finish`, plus the reservation checks in `ask`, `converse` and `down`.**
   Decisions 1–10.
   - **Argument parsing:** `finish` (today `finish() { local role=${2:-} …`) parses its flags after `<task> <role>`,
     like `up` does.
   - **The loop** goes after the reservation (`trap release EXIT`) and before the graceful quit
     (`if alive "$pid" "$start" && same_pane …`).
   - **The failure chain** replaces today's `if … elif …` block with appends to a `failures` array.
   - **Reservation checks:**
     - add `reserved "$f"` refusals near the existing `conv_held` refusals in `converse` and `down`;
     - in `ask`, add the refusal inside the existing `lock … update … pending` block (decision 9), with the
       exact pid and start exemption.
   - Verify:
     - `shellcheck --exclude=SC2016 home/development/herdr-team.sh`;
     - the existing suite through the temp-tool recipe passes:

       ```bash
       t=$(mktemp); printf 'agy_member=false\nsink_path=%s\n' "$(command -v herdr-team-sink)" >"$t"
       cat home/development/herdr-team.sh >>"$t"; chmod +x "$t"
       bash home/development/herdr-team-test.sh "$t" </dev/null
       ```

   - Traps:
     - `ask` exits through `refuse` and `fail`, so call it only in `$( )`;
     - compare `fingerprint` values as strings;
     - `HERDR_TEAM_RETRY_TIMEOUT` is for tests only, so don't document it as a user flag;
     - the member key list is the one `up` uses for `review` (search `-u ANTHROPIC_API_KEY`).
3. **`home/development/herdr-team-test.sh`: the cases from the spec's Verification:**
   - pass;
   - retry fixes it;
   - still failing;
   - retry timeout (`HERDR_TEAM_RETRY_TIMEOUT=2`);
   - retry `agent_gone`;
   - the check dirties the tree, single and across retries;
   - all failures shown;
   - the guards: `main` gives `verify_unsafe`, a detached `HEAD` at `origin/main` gives `verify_unsafe`, a
     feature branch at `origin/main`'s commit passes, and `--retries 5` is a usage error;
   - concurrency: an external `ask` during `finish --verify` gets `busy`, while `finish`'s own retry `ask`
     proceeds;
   - unchanged: no `--verify`.

   For the `origin/main` cases, add a bare repo as `origin` in a local copy of the test repo.

   The fake agent is controlled through `$TEST_STATE` files, as the existing cases do (`arm`, `reply`, `quit`).
   - Verify: the suite passes 20 times in a row through the temp-tool recipe.
   - Traps: clean up any helper processes in `reset` and `cleanup`.
4. **`docs/applications/herdr.md` and the skills:**
   - **Docs:** under the `finish` bullet, describe `--verify`, `--retries` and `--verify-timeout`, the `verify`
     and `failures` fields, and the `busy` refusals during a finish.
   - **Skills:** in the `handoff` skill (`home/development/claude-code-skills/handoff/SKILL.md`) and the `/team`
     command (the `teamCommand` text in `home/development/claude-code-commands/default.nix`, installed at :128),
     say to pass the plan step's check as `--verify`.
   - Verify: `npx --no markdownlint-cli2` on the changed Markdown.
   - Traps: markdownlint lints whole files.
5. **Lead: build, review, ship.**
   - Run `just check-syntax`, `just test-host p620` and `just test-host razer`. The herdr-team checkPhase runs the
     suite.
   - Review: a fresh Opus pass plus the Codex and agy `reviewers:` on `git diff origin/main`.
   - Open a PR linking the intent, spec and plan.
   - Announce on the bus, then `just p620` and `just deploy-via-p620 razer`.
   - Live check on p620: one real implementer step whose `--verify` check fails first and passes after one retry.

## Tests

| Command | Expected |
| ------- | -------- |
| shellcheck on both scripts | clean |
| the suite through the temp-tool recipe, 20 runs | 20/20 |
| `just test-host p620` and `just test-host razer` | both build |
| the live check | `ok: true`, `verify.attempts == 2` |

## Rollback

Revert the merge commit and deploy p620 and razer. Without `--verify`, nothing changes for callers, so a
partial rollback is not needed.

## Amendments (2026-11-10, from agy's plan review; no decision changed)

- **The retry call** is `res=$(ask "$task" "$role" "$req" --timeout "${HERDR_TEAM_RETRY_TIMEOUT:-1800}") || :`.
  `writeShellApplication` runs under `set -e`, and `converse` guards the same call at herdr-team.sh:686. The
  temp-tool recipe also gets `set -euo pipefail` as its first header line, so local runs match the packaged
  shell.
- **The reservation check in `ask`** runs twice:
  - next to the early `conv_held` refusal (:450), which also covers `--resume`;
  - inside the `lock … pending` block (:485).

  Both use the exact pid and start exemption.
- **`verify_unsafe`** stops the loop before the command runs.
  - `verify.attempts` counts the checks that actually ran, and `verify.exit` is `null` if none ran.
  - `verify_failed` is appended only when a check ran and its last exit was non-zero.
- **The 4 KB tail:** drop NULs first, then the UTF-8 continuation bytes (`0x80`–`0xBF`) at the front of the
  slice. This is the mirror of `cut_msg`, which trims the end.

## Deviations

- Step 3 (coder):
  - The `verify-*` cases add a bare `origin` remote to the shared test repo, so the `verify_unsafe` case for "detached
    at `origin/main`" can run, and remove it at the end of the block.
  - The temporary tool the suite runs drops the `#!` line of the packaged script; the cases call it through `bash`.
  - 20 runs in a row passed, each with the ten `verify-*` cases.
- Review fixes (Opus, Codex, agy): `finish` takes its member, conversation and pending checks under the lock and
  `down` checks the reservation under the lock; the check runs through `agent-env` with `</dev/null`,
  `timeout -k 10` and output capped at 64 KB; the fingerprint is refreshed after each retry; an empty outcome counts
  as `failed`; `--verify ''` is a usage error. A TERM-ignoring check records exit 137 (the KILL from `timeout -k`),
  not 124. Five new `verify-*` cases, and `no_leftovers` checks for `verify-*` temp files. Two full runs passed.
- Codex PR review: the check's output went through `| tail`, which `timeout` does not cover, so a check that left a
  background child holding stdout blocked `finish`. The check now writes straight to its file; `timeout` leads its
  own process group, which is killed after the run, and the output is capped to 64 KB afterwards. New case
  `verify-background-child`.
