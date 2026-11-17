---
status: approved
issue: 2988
spec: spec/2026-11-16-2988-herdr-team-provider-scan.md
coders:
  1: codex # small, tricky text parsing in a shell script (awk error-line reconstruction)
  2: codex # the tests pin the same parsing rules; same author keeps them consistent
reviewers:
  - codex # independent read of the parser and tests against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: herdr-team's provider-error scan only matches real provider errors

Branch `fix/2988-herdr-team-provider-scan`, worktree `~/.config/nixos-2988`, stacked on
`feat/2978-herdr-app-parity` (PR #2990, which edits the same file). The PR targets that branch until #2990 merges.

## Approved decisions (from the spec)

- `herdr-team ask` ends a wait with `provider_error` when the count of matching lines on the member's screen
  rises above the count at send time (`pbase`). Today a "matching line" is any line containing a `perr` phrase.
  After this change it is a reconstructed provider-error line containing a phrase.
- Error lines: a line whose first non-space characters are `■` (Codex: `format!("■ {message}")`) or `agy error:`
  (`agy-acp-member.py`). Codex wraps an error at column zero, so following non-blank lines are joined to it (with
  one space) until a blank line, another `■` or `agy error:` line, or six continuation lines.
- Phrases: the existing `perr` list plus `hit your usage limit`, `Policy-restricted capacity is unavailable`,
  `Flex capacity unavailable`. Case-insensitive fixed strings, as now.
- `<n>.screen` holds the reconstructed error lines that contain a phrase.
- The baseline rule and every other outcome (`interrupted`, `agent_gone`, `timeout` …) stay as they are. Retries
  (status indicator, no `■`) keep the wait going.

## Steps

- **Step 1:** `home/development/herdr-team.sh:937-945`.
  - Add the three phrases to `perr`.
  - Add `perr_lines() { …; }` printing the reconstructed error lines of `$1` (gawk; `gawk` is in the package's
    `runtimeInputs`, `home/development/agent-run.nix:20`).
  - `perr_count` becomes `perr_lines "$1" | grep -ciF "${pargs[@]}" || :`.
  - Line 1076 becomes `perr_lines "$screen" | grep -iF "${pargs[@]}" >"$work/ans/$n.screen" || :`.
  - Lines 1006 and 1017 (`pbase`) are unchanged and so use the new count.
  Check: `bash -n`; `shellcheck --exclude=SC2016` clean.
  Traps: the script runs under `set -euo pipefail` (writeShellApplication), so a grep with no match inside a
  pipeline must not abort (`|| :` stays at the end); `■` is multibyte, so match it as a literal string in awk
  (`index()` or a literal regex), never a bracket class (under `LC_ALL=C`, `[■]` also matches `●`), and never
  strip it by a fixed character count (`length("■")` is 3 under `C`, 1 under UTF-8); keep the awk in one function,
  no new files.

- **Step 2:** `home/development/herdr-team-test.sh:415-435`, the provider cases (fake TUI screen via
  `$TEST_STATE/screen`; the fake makes a turn file only when it receives a prompt, `:124`, and `--resume` sends
  nothing, `herdr-team.sh:1000`). Harness rules for every new case:
  - positive cases (expect `provider_error`): start a fresh ask in the background with a long `--timeout` (20 s,
    as at `:427`), wait until the pending request exists in the state file (bounded poll, not a fixed sleep), then
    write the screen and `wait` for the result;
  - negative cases (expect no trigger): a foreground ask with `--timeout 1-2` and the screen already written, then
    assert `timeout`; close the pending request before the next case the way the suite already does for a timed
    out ask (resume with an injected matching turn JSON as at `:487`, which also proves `ok` wins), so the next
    fresh ask does not return `busy`.
  Cases:
  - baseline: a recognised stale `■ You've hit your usage limit. Try again later` on screen at send time and no
    reply → `timeout`, and the stored `pending.perr` is 1; then add a blank line and a second `■` error and resume
    → `provider_error` (proves the baseline and blank-line separation);
  - the existing case at `:430`, with `■ You've hit your usage limit. Try again later` and
    `agy error: Quota exceeded for today` → `provider_error`, `3.screen` has exactly those two lines;
  - `grep: rate limit exceeded` and a code line listing phrases (`perr=("Usage limit reached" "rate limit
    exceeded")`) → `timeout`, then the injected turn → `ok`;
  - `■ Policy-restricted capacity is` / `unavailable. Please try again` → `provider_error`;
  - `■ Your request failed because the` / `Selected model is at capacity.` → `provider_error`;
  - `■ Flex capacity unavailable.` → `provider_error`;
  - `■ Copy failed: clipboard busy`, `Reconnecting… rate limit exceeded` and `● rate limit exceeded` → `timeout`;
  - the wrapped-error case once more under `LC_ALL=C`.
  Check: `nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link` succeeds; the
  `herdr-team` package's `checkPhase` (`home/development/agent-run.nix:22-28`) runs shellcheck and this suite.
  Also make one case fail on purpose (revert the step 1 filter locally) and see the build fail, then restore.

- **Step 3 (lead):** in order:
  - a local `deploy/` branch from the finished `fix/2988-herdr-team-provider-scan`, merging
    `origin/feat/2978-herdr-app-parity`, `origin/fix/2987-hc-argv-scope` and `origin/fix/gnome-file-picker`, so the
    hosts keep the open branches;
  - on that branch, `just test-host p620` and `just test-host razer` (the `herdr-team` `checkPhase` runs the suite);
  - bus `read_new("#agents:freundcloud.org.uk")` + `post`; `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620`
    and `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`.
  Live check on p620: `herdr-team up s2988 review`; `ask` with a prompt telling the member to run
  `grep -n 'rate limit' home/development/herdr-team.sh`, then wait 30 seconds before answering "done". While the
  ask is pending, `herdr pane read` the member pane and confirm the grep output with the phrase is on screen; the
  final outcome is `ok`, not `provider_error`. Then `herdr-team down s2988`.

- **Step 4 (lead):** commit per step, push, PR (links intent, spec, plan; steps Codex did), Opus review of the diff,
  `@codex review`.

## Tests

- Step 2's suite in the `herdr-team` build on every host.
- `just test-host p620`, `just test-host razer`; step 3's live ask.

## Rollback

Revert the step 1 and step 2 commits together (the new tests fail against the old scan, and they run in the build),
build, then switch; or boot the previous generation. The scan goes back to whole-screen phrase matching. Nothing
else depends on it.
