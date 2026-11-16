---
status: draft
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
    `runtimeInputs`, `home/development/agent-run.nix:21`).
  - `perr_count` becomes `perr_lines "$1" | grep -ciF "${pargs[@]}" || :`.
  - Line 1076 becomes `perr_lines "$screen" | grep -iF "${pargs[@]}" >"$work/ans/$n.screen" || :`.
  - Lines 1006 and 1017 (`pbase`) are unchanged and so use the new count.
  Check: `bash -n`; `shellcheck --exclude=SC2016` clean.
  Traps: the script runs under `set -euo pipefail` (writeShellApplication), so a grep with no match inside a
  pipeline must not abort (`|| :` stays at the end); `■` is multibyte, so match it as a literal string in awk
  (`index()` or a literal regex), not a bracket class; keep the awk in one function, no new files.

- **Step 2:** `home/development/herdr-team-test.sh:415-435`, the provider cases (fake TUI screen via
  `$TEST_STATE/screen`):
  - line 419 fixture: `■ You've hit your usage limit. Try again later` (stale, still `ok`);
  - line 430 fixture: `■ You've hit your usage limit. Try again later` plus `agy error: Quota exceeded for today`
    after the send → `provider_error`, and `3.screen` has exactly those two lines;
  - new cases, each in the existing `--resume`/background style, each ending in the asserted outcome:
    an unprefixed phrase (`grep: rate limit exceeded`) → `timeout` (short `--timeout`), and `ok` when a reply file
    exists; `■ Policy-restricted capacity is` / `unavailable. Please try again` → `provider_error`;
    `■ Your request failed because the` / `Selected model is at capacity.` → `provider_error`;
    `■ Flex capacity unavailable.` → `provider_error`; `■ Copy failed: clipboard busy` and
    `Reconnecting… rate limit exceeded` → `timeout`; a stale `■` error, a blank line, and a new `■` error →
    `provider_error`.
  Check: `nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link` succeeds; the
  `herdr-team` package's `checkPhase` (`home/development/agent-run.nix:22-28`) runs shellcheck and this suite.
  Also make one case fail on purpose (revert the step 1 filter locally) and see the build fail, then restore.
  Traps: keep timeouts short (1-3 s) so the suite stays fast; reset `$TEST_STATE/screen` and `reply` between cases
  as the surrounding tests do.

- **Step 3 (lead):** `just test-host p620` and `just test-host razer` (the `herdr-team` `checkPhase` runs the
  suite). Then deploy, from a local stack with the open herdr branches so the hosts keep them: merge
  `origin/feat/2978-herdr-app-parity`, `origin/fix/2987-hc-argv-scope` and `origin/fix/gnome-file-picker` into a
  local `deploy/` branch; bus `read_new` + `post`; `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620` and
  `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`.
  Live check on p620: `herdr-team up s2988 review`, then `ask` with a prompt telling the member to run
  `grep -n 'rate limit' home/development/herdr-team.sh` and answer "done": the outcome is `ok`, not
  `provider_error`; `herdr-team down s2988`.

- **Step 4 (lead):** commit per step, push, PR (links intent, spec, plan; steps Codex did), Opus review of the diff,
  `@codex review`.

## Tests

- Step 2's suite in the `herdr-team` build on every host.
- `just test-host p620`, `just test-host razer`; step 3's live ask.

## Rollback

Revert the step 1 commit and switch: the scan goes back to whole-screen phrase matching. Nothing else depends on it.
