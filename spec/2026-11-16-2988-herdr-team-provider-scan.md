---
status: draft
issue: 2988
intent: intent/2026-11-16-2988-herdr-team-provider-scan.md
---

# Spec: herdr-team's provider-error scan only matches real provider errors

## Design

All in `home/development/herdr-team.sh` around `perr` (line 937) and the `ask` loop (line 1074).

1. **Error lines first, phrases second.** A new `perr_lines` reads the screen and prints only provider-error
   lines, each joined with its wrapped continuation:
   - a Codex error starts with `■` after optional leading spaces (Codex renders terminal errors as
     `format!("■ {message}")`); following lines that start with spaces and are not blank are the same message
     wrapped by the TUI, so they are appended to it;
   - an agy error starts with `agy error:` after optional leading spaces (`agy-acp-member.py`).

   `perr_count` then counts those lines that contain a `perr` phrase (`grep -ciF`, as now), and the `.screen`
   evidence file is the same filtered lines. One awk program, no new dependency (gawk is already in
   `runtimeInputs`).

2. **Phrase list.** Keep the current phrases and add the Codex 0.169 messages the list misses:
   `hit your usage limit` (Codex's current usage-limit text, "You've hit your usage limit…"),
   `Policy-restricted capacity is unavailable` and `Flex capacity unavailable`. `■ Conversation interrupted` has no
   phrase in the list, so it stays the separate `interrupted` outcome.

3. **Baseline unchanged.** `pbase` is still `perr_count` of the screen at send time, and only a higher count ends
   the wait.

4. **Retries keep waiting** (the intent's recommendation): Codex shows retry progress in its status indicator,
   without `■`, so a retry that succeeds no longer ends the wait; a final failure prints a `■` line and is caught.

## Alternatives rejected

- Any `■` line counts, without the phrase list: also catches benign UI errors (`■ Copy failed`, `■ Export failed`)
  and would end a healthy turn.
- Match only the last screen line: the error is often followed by Codex's prompt and status lines.
- Read Codex's structured events (app-server or session JSONL) instead of the screen: right in the long run, but a
  much larger change across both backends; the screen scan is what `ask` has.

## Risks

- A Codex release that changes the `■` prefix makes real errors go unnoticed until the timeout (900 s default):
  slower, not wrong. The test pins the shape; a bump that changes it shows up as a timeout in practice.
- A member printing an exact error line on purpose still triggers it (accepted in the intent).
- Hosts: p620 and razer through Home Manager; no services.

## Verification

`home/development/herdr-team-test.sh`, run by the `herdr-team` package's `checkPhase` on every build:

- The existing provider-error test (line 426) uses verified shapes: `■ You've hit your usage limit…` and
  `agy error: Quota exceeded for today`; `provider_error` with exactly those lines in `<n>.screen`.
- New: an unprefixed phrase (`grep: rate limit exceeded`, a code line listing the phrases) appears after the
  send and the turn times out instead; with a completed turn file the outcome is `ok`.
- New: a `■` error wrapped over two lines where the phrase is on the continuation line is caught.
- New: `■ Copy failed: …` with no phrase does not trigger.
- The stale-error test (line 418) keeps passing.

Then `just test-host p620` and `razer`, deploy (stacked on #2990), and a live `herdr-team ask` on p620 where the
member greps `herdr-team.sh` for the phrase list: the outcome is `ok`, not `provider_error`.
