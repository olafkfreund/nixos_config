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
2. **New, `--verify` only:** refuse with `refuse` (no reservation leak, because the EXIT trap releases it) when
   either is true:
   - `realpath "$root"` equals `realpath -m ~/.config/nixos`;
   - `lg branch --show-current` is `main`, or `HEAD` is detached at `origin/main`'s commit.

   This re-checks at finish time what `up` checked at start (herdr-team.sh:223–228).
3. **New, the verify loop.** For attempt `a = 1 … retries+1`:
   1. `fp_pre=$(fingerprint)`, the tree as the implementer left it.
   2. Run the check.
      - The command is `(cd "$root" && timeout "$vt" env -u <key list> bash -c "$cmd") >"$out" 2>&1`.
      - `<key list>` is the same list the members use, including `ANTHROPIC_API_KEY_FILE` after #2818.
      - `$out` is a `mktemp` file under `$rt` (0700), removed on exit.
      - Exit 124 means timed out.
   3. `fp_post=$(fingerprint)`. If it differs from `fp_pre`, the check changed the tree (build output, caches).
      Record `dirtied: true`.
   4. If the exit is 0, stop the loop.
   5. If `a > retries`, stop: the check failed.
   6. Otherwise, write a retry request to a `mktemp` file:
      - a fixed header saying it is from the lead;
      - the command;
      - the exit code;
      - the last 4 KB of `$out`.

      Then call `res=$(ask "$task" "$role" "$req" --timeout 1800)`, the same in-process call `converse` uses
      (herdr-team.sh:686). If `res`'s `outcome` is not `ok`, stop at once and record `retry_outcome` (for example
      `timeout`). The request stays pending, and `finish` goes on to tear the member down, which clears it.
4. **The implementer's fingerprint** is `fp_pre` of the last attempt that ran: the tree the implementer
   produced, before any changes made by the check itself.
5. The graceful quit (`ctrl+c`) and `teardown`, as today.
6. **`last` is read after the verify loop**, not before as today (herdr-team.sh:801). A retry's answer counts,
   and a retry that did not answer leaves the earlier `last`. Step 3.6 already stopped and recorded the failure
   in that case, so it cannot pass silently.
7. The reason chain runs as today, with two changes:
   - "empty diff" compares the up-time `fp` with the implementer's fingerprint from step 4, instead of a fresh
     `fingerprint`, when `--verify` ran. Without `--verify`, it is unchanged.
   - New, last in the chain, so it never masks the safety reasons: `verify_failed` when the check's final exit
     is not 0, and `verify_retry_<outcome>` when a retry did not answer `ok`.

**Output.** The JSON gains `verify`: `null` without `--verify`, otherwise:

```json
{"cmd": "...", "ok": true, "exit": 0, "attempts": 1, "dirtied": false, "retry_outcome": null, "tail": "..."}
```

The check's own result is always visible here, even when `reason` reports a safety failure such as
`HEAD moved`.

**Skills.** The `handoff` and `team` skills say: when a plan step names a check, pass it as `--verify` to
`herdr-team finish`.

## Alternatives rejected

- **Running the check after the implementer has quit:** this loses the live session, which is the point of
  the issue.
- **A list of all failure reasons instead of one `reason`:** that changes the contract every caller parses.
  `verify` carries the check's result separately, so nothing is hidden.
- **Letting a member's reply supply or change the command:** the lead's command is the only input (intent
  constraint).
- **A sandbox for the check:** the check is trusted because the lead wrote it (intent constraint). A working
  directory is not a sandbox.
- **A configurable retry-answer timeout:** 1800 s is generous, and it can be added later if a step needs it.

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

- **pass:** the check exits 0 on the first try. `ok: true`, `verify.attempts == 1`, and no request is sent.
- **retry fixes it:** the check fails first, the fake agent's answer makes a file appear, and the second run
  passes. `attempts == 2`, a prompt was logged, `ok: true`.
- **still failing:** `ok: false`, `reason == "verify_failed"`, `verify.exit` non-zero, and the implementer is
  stopped.
- **retry not answered:** the fake agent gives no turn. Then `reason == "verify_retry_timeout"` and `ok: false`,
  using a short `--timeout` via a test hook or the fake agent's quit.
- **check dirties the tree:** the implementer changed nothing and the check creates `out.log`. Then
  `reason == "empty diff"` and `verify.dirtied == true`.
- **safety first:** the implementer moved `HEAD` and the check fails. Then `reason == "HEAD moved"` and
  `verify.ok == false`.
- **guards:** `--verify` with the worktree on `main` is refused. `--retries 5` is a usage error.
- **unchanged:** `finish` without `--verify` gives the same JSON as today, plus `verify: null`.

Then `shellcheck`, `just test-host p620` and `razer`. Live on p620: a real implementer step with a check that
fails first, for example `shellcheck` on a file it must fix, and passes after one retry.
