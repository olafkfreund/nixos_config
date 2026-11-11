---
status: draft
issue: 2863
spec: spec/2026-11-11-2863-herdr-team-agent-rename.md
coders:
  1: codex   # small, tricky shell logic (locale, exit status under set -e)
  2: coder   # test fixtures and cases, ordinary edits
reviewers:
  - codex    # independent read of the diff against this plan
  - agy      # second independent read; found the locale trap at spec review
---

# Plan: herdr-team names Codex members with valid herdr agent names

Self-contained summary of the approved decisions:

- herdr 0.9.5 agent names must match `^[a-z][a-z0-9_-]{0,31}$` and be
  unique. A rejected name fails with `invalid_agent_name`, a taken one with
  `agent_name_taken`, both as JSON on stderr. A rename leaves `.agent`
  unchanged.
- Task names stay as `task_ok` accepts them. A new `agent_name` maps
  `<task>-<role>` to a valid name: byte-wise lowercase under `LC_ALL=C`,
  other bytes become `-`, a `t` prefix when it doesn't start with a letter,
  and the task part is cut to `31 - len(role)` before `-<role>` is added.
- The Codex rename keeps herdr's stderr in the reason and stays fatal.
  Only on `agent_name_taken` does it retry once, with `-${gen:0:4}` added
  to the role.
- agy's `pane rename`, the tab label, scopes, state and relay headers are
  unchanged.

## Steps

1. **`home/development/herdr-team.sh`** (coder: codex).
   - After `task_ok` (line 60), add:

     ```bash
     # herdr agent names: ^[a-z][a-z0-9_-]{0,31}$; shorten the task, never the role
     agent_name() {
       local t
       t=$(printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C tr -c 'a-z0-9_-' '-')
       [[ $t == [a-z]* ]] || t=t$t
       printf '%s-%s' "${t:0:$((31 - ${#2}))}" "$2"
     }
     ```

   - Add `err name` to `up`'s `local` line (line 346).
   - Replace line 579 (`h agent rename … || fail 'agent rename failed'`)
     with:

     ```bash
     name=$(agent_name "$task" "$role")
     if ! err=$(h agent rename "$pane" "$name" 2>&1 >/dev/null); then
       [[ $err == *agent_name_taken* ]] || fail "agent rename failed${err:+: ${err//$'\n'/ }}"
       name=$(agent_name "$task" "$role-${gen:0:4}")
       err=$(h agent rename "$pane" "$name" 2>&1 >/dev/null) || fail "agent rename failed${err:+: ${err//$'\n'/ }}"
     fi
     ```

   - Check: `bash -n home/development/herdr-team.sh` and
     `shellcheck --exclude=SC2016 home/development/herdr-team.sh`.
   - Traps:
     - the file runs under `set -euo pipefail`, so keep the `local`
       separate from the assignment;
     - `gen` is set earlier in `up` (lines 396/402);
     - don't touch line 577 (agy).

2. **`home/development/herdr-team-test.sh`** (coder: coder).
   - In the fake `herdr`, replace `rename) exit 0 ;;` (line 109) with a
     check that:
     - if `$TEST_STATE/bad-agent-rename` exists, prints
       `{"error":{"code":"test_bad","message":"injected rename error"}}` to
       stderr and exits 1;
     - if `$TEST_STATE/taken-agent-rename` exists, removes it, prints
       `{"error":{"code":"agent_name_taken","message":"taken"}}` to stderr
       and exits 1;
     - if `$4` doesn't match `^[a-z][a-z0-9_-]{0,31}$`, checked with
       `LC_ALL=C`, prints an `invalid_agent_name` JSON to stderr and exits 1;
     - otherwise exits 0.

     Keep the logging line (line 45) and the existing `fail-*` hook (line
     46) as they are.
   - Add cases next to the `fails` block (around line 819), each followed by
     the file's usual `reset`:
     - `up 2863 review`: success; the log has `agent rename <pane>
       t2863-review`.
     - `up PR-2863 review`: the log has `pr-2863-review`.
     - A 40-character task with `implement`: the logged name is 32
       characters and ends in `-implement`.
     - `taken-agent-rename`: success; two `agent rename` lines, the second
       matching `t2863-review-[0-9a-f]{4}`.
     - `bad-agent-rename`: `up` fails, `reason` contains `injected rename
       error`, and `no_leftovers` passes.
   - Check: run the suite as the `checkPhase` does. That is step 3's build;
     a direct run is `bash home/development/herdr-team-test.sh <built
     herdr-team>`.
   - Traps:
     - read how existing cases capture `code` and the JSON (`team`/`up`
       helpers) and reuse them;
     - the fake's `$3` is the pane and `$4` the name;
     - never call the real `herdr`.

3. **Build (lead).** Build the `herdr-team` package (its `checkPhase` runs
   shellcheck and the suite), then `just test-host p620` and
   `just test-host razer`. Also confirm the new cases fail against the old
   line 579: temporarily restore that one line in a scratch copy, run the
   suite, and expect failures.
4. **Review (lead).** A fresh Opus review gets only this plan and
   `git diff origin/main...HEAD`, and Codex and agy review read-only
   (`reviewers:`). Check `git status --porcelain` before and after. Fix,
   rebuild.
5. **PR, merge, deploy (lead).**
   - Open a PR linking the intent, spec and plan; say which steps Codex and
     the coder did. Merge once CI is green.
   - Announce on `#agents:freundcloud.org.uk`, then deploy p620
     (`just p620`) and razer (`just deploy-via-p620 razer`), and post the
     outcome.
6. **Live checks, p620 (lead).**
   - In this worktree, `herdr-team up 2863 review` returns `ok: true`, and
     `herdr agent list` shows `t2863-review` with `agent: "codex"`.
   - `herdr-team ask 2863 review` with a one-line prompt returns
     `ok: true`.
   - In a second worktree, `herdr-team up t2863 review` returns `ok: true`
     with a `t2863-review-<4 hex>` name.
   - `down` both, then comment the results on #2863 and close it.

## Tests

| Command | Expected |
|---|---|
| `bash -n`, `shellcheck --exclude=SC2016` on herdr-team.sh | clean |
| package build (`checkPhase` runs the suite) | passes, new cases included |
| suite against the old line 579 | new cases fail |
| `just test-host p620`, `just test-host razer` | build |
| step 6 live checks | `ok: true`, names as above |

## Rollback

Revert the PR and redeploy p620 and razer. Until then, use a task name that
starts with a letter (`t2863`), or headless `agent-run codex`.
