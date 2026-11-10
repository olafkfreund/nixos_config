---
status: draft
issue: 2829
intent: intent/2026-11-10-2829-herdr-team-finish-verify.md
---

# Spec: `herdr-team finish --verify`

## Design

All changes are in `finish` in `home/development/herdr-team.sh`, plus its tests and docs. Without `--verify`,
the code path is unchanged.

**Arguments.**

```text
herdr-team finish <task> implement|agy-implement [--verify '<cmd>'] [--retries N] [--verify-timeout S]
```

- `--retries` defaults to 1, allows 0–3, and anything else is a usage error.
- `--verify-timeout` defaults to 900 s and must be a positive integer.

**Order inside `finish`** (today's steps are marked "as today"):

1. Validate and take the reservation, as today.
   - `finish` gains `trap 'exit 130' INT`, `trap 'exit 143' TERM` and `trap 'exit 129' HUP`, as `up` and
     `converse` have, so the EXIT trap (`release`) always runs.
   - `release` also removes the temp files of step 3.
2. **New, `--verify` only:** read `pre_last` (the member's `.last.outcome`) and the up-time `fp`. Set
   `fp_impl=$(fingerprint)`, the tree as the implementer left it, and `dirtied=false`.
3. **New, the verify loop.** For attempt `a = 1 … retries+1`:
   1. **Guard**, before every attempt, because an unrestricted member may have switched branches during a
      retry. Refuse (`verify_unsafe`) if any of these is true:
      - `realpath "$root"` equals `realpath -m ~/.config/nixos`;
      - `lg branch --show-current` is `main`;
      - the branch is empty (detached), `origin/main` exists (`lg rev-parse -q --verify origin/main`), and it
        equals `HEAD`.

      A named feature branch still at `origin/main`'s commit passes. A test repo without `origin` passes.
   2. `fp_pre=$(fingerprint)`. If `a > 1` and `fp_pre != fp_post` of the previous attempt, the implementer
      changed the tree during the retry, so `fp_impl=$fp_pre`. Otherwise `fp_impl` is kept. Check output
      therefore never becomes "the implementer's change".
   3. Run the check:
      - The command is `(cd "$root" && timeout "$vt" env -u <key list> bash -c "$cmd") >"$out" 2>&1`.
      - `<key list>` is the members' list, including `ANTHROPIC_API_KEY_FILE` (#2818).
      - `$out` is a `mktemp` file under `$rt`.
      - Exit 124 means timed out.
   4. `fp_post=$(fingerprint)`. If `fp_post != fp_pre`, set `dirtied=true`, which sticks across attempts.
   5. If the exit is 0, stop the loop.
   6. If `a > retries`, stop: the check failed.
   7. Otherwise, write the retry request to a `mktemp` file:
      - a fixed header from the lead;
      - the command;
      - the exit code;
      - the last 4 KB of `$out`, trimmed on a UTF-8 boundary with NULs removed. That uses the `cut_msg`
        approach (herdr-team.sh:596).
   8. Call `res=$(ask "$task" "$role" "$req" --timeout "${HERDR_TEAM_RETRY_TIMEOUT:-1800}")`, the same
      in-process call `converse` uses (:686). The env override exists for the tests.
      - If `outcome` is `ok`, go to the next attempt.
      - Otherwise set `retry_outcome` to that outcome and stop the loop at once. A `timeout` or `cancelled`
        leaves the request pending; teardown clears it.
4. **Before** the graceful quit and `teardown`, which delete the member record, read `last` as today
   (:801). A retry's `ok` answer updates it.
5. The graceful quit (`ctrl+c`) and `teardown`, as today.
6. **Failures.** Every check below that fails is appended, in this order, to a `failures` array:

   | Failure | Condition |
   | ------- | --------- |
   | `not_exited` | as today |
   | `tool exited N` | as today |
   | `verify_unsafe` | the guard in step 3.1 refused |
   | `verify_retry_<outcome>` | a retry did not answer `ok`. It replaces `last outcome is …` for that case, so `agent_gone`, `interrupted`, `empty` and the rest are named as retry failures |
   | `last outcome is …` | as today, when `pre_last` was not `ok` and no retry answered `ok` |
   | `HEAD moved`, `changes are staged` | as today |
   | `empty diff` | `fp_impl == fp` when `--verify` ran, else as today |
   | `verify_failed` | the check's final exit is not 0 |

   `reason` stays the first entry, so today's callers keep working, and `failures` lists them all.

**Concurrency.** `ask`, `converse` and `down` without `--force` refuse with `busy` while a `finish` holds the
task's reservation (`reserved "$f"`). A verify run can last minutes, so another caller must not type into
the implementer mid-check. `finish`'s own retry `ask` is exempt: it passes the reservation holder's pid.

**Output.** The JSON gains `failures` (an array, empty when `ok`) and `verify`. `verify` is `null` without
`--verify`, otherwise:

```json
{"cmd": "...", "ok": true, "exit": 0, "attempts": 1, "dirtied": false, "retry_outcome": null, "tail": "..."}
```

**Skills.** The `handoff` and `team` skills say: when a plan step names a check, pass it as `--verify` to
`herdr-team finish`.

## Alternatives rejected

- **Running the check after the implementer has quit:** this loses the live session, which is the point of
  the issue.
- **Replacing `reason` with a list:** that would break every caller that parses `reason`. `failures` is added
  next to it instead.
- **Letting a member's reply supply or change the command:** the lead's command is the only input (intent
  constraint).
- **A sandbox for the check:** the check is trusted because the lead wrote it (intent constraint). A working
  directory is not a sandbox.
- **A retry-answer timeout flag:** 1800 s is generous. `HERDR_TEAM_RETRY_TIMEOUT` exists only for the tests.
- **Deleting files the check created:** that removes the lead's own build output, and it cannot tell them from
  implementer files at the same path. Tracking `fp_impl` avoids both problems.

## Risks

- **A check that hangs:** bounded by `--verify-timeout`, and `timeout` kills it.
- **A check that writes outside the worktree:** the lead's responsibility, the same as any command the lead runs.
- **Output with secrets:** the tail goes into a request file in the member's 0700 work dir and into the
  `finish` JSON. The check runs with the key variables unset. Lead-chosen commands such as test suites do not
  print secrets.
- **`fingerprint` cost:** two extra calls per attempt, each reading the tree. That is fine for repo-sized
  trees.
- **Hosts:** p620 and razer through Home Manager. Only herdr-team is affected.

## Verification

`home/development/herdr-team-test.sh` gains these cases:

- **pass:** the check exits 0 on the first try. `ok: true`, `attempts == 1`, no prompt is logged, and
  `failures == []`.
- **retry fixes it:** the first check fails. The fake agent's answer creates a file, the second check passes.
  Then `attempts == 2`, one prompt is logged, and `ok: true`.
- **still failing:** `failures` ends with `verify_failed`, `verify.exit` is non-zero, and the implementer is
  stopped.
- **retry timeout:** with `HERDR_TEAM_RETRY_TIMEOUT=2` and no turn from the fake agent,
  `reason == "verify_retry_timeout"`. The member is gone afterwards, so no pending request outlives `finish`.
- **retry agent_gone:** the fake agent quits on the retry. `reason == "verify_retry_agent_gone"`, not
  `last outcome is …`.
- **check dirties, single attempt:** the implementer changed nothing, and the check creates `out.log` and
  passes. Then `reason == "empty diff"` and `dirtied == true`.
- **check dirties across retries:** the first check creates `out.log` and fails. The agent answers `ok` without
  changing files, and the second check passes. Still `reason == "empty diff"`.
- **all failures shown:** the implementer moves `HEAD` and stages a change, and the check fails. Then
  `reason == "HEAD moved"`, and `failures` contains `changes are staged` and `verify_failed`.
- **guards:**
  - a worktree on `main` gives `verify_unsafe`;
  - a detached `HEAD` at `origin/main` gives `verify_unsafe`;
  - a feature branch at `origin/main`'s commit passes;
  - `--retries 5` is a usage error.
- **concurrency:** an `ask` while `finish --verify` runs is refused with `busy`.
- **unchanged:** `finish` without `--verify` gives today's JSON, plus `failures` and `verify: null`.

Then `shellcheck`, `just test-host p620` and `razer`. Live on p620: a real implementer step whose check fails
first and passes after one retry.
