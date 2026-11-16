---
status: draft
issue: 2988
author: olafkfreund
---

# Intent: herdr-team's provider-error scan only matches real provider errors

## Problem

While `herdr-team ask` waits for a member's answer, it scans the member's whole screen for provider-failure strings
(`perr` in `home/development/herdr-team.sh:937`: "rate limit exceeded", "Quota exceeded", "agy error:" …). A new
match ends the wait with `outcome: provider_error` and drops the pending request.

The scan matches any text on screen, not only the provider's own error lines. During #2978 a Codex implementer
read `herdr-team.sh` itself; the file's `perr` list appeared in its tool output, `ask` returned `provider_error`, and
the lead had to wait on the pane by hand while the member kept working. The same happens whenever a member reads or
prints logs, docs or code containing one of those phrases: a review of herdr-team, a grep of a log, a test
fixture.

## Proposed outcome

`ask` (and `converse`) return `provider_error` only when the provider itself reports an error: Codex's own error
lines (Codex 0.169 prints them as `■ <message>`, the same marker as `■ Conversation interrupted`) and
`agy-acp-member`'s `agy error:` lines. Text that merely contains a phrase, anywhere else on screen, no longer ends
the wait. Real provider failures are still caught, with their lines saved to `<n>.screen` as now.

## Affected users and systems

- `home/development/herdr-team.sh` and `home/development/herdr-team-test.sh` (the `ask` loop and `perr_count`).
- Every herdr-team task on p620 and razer (TUI and herdr-app backends); the `second-opinion` and `handoff` skills
  that rely on `ask`.

## Constraints

- No missed real failures: a usage-limit or capacity error must still end the wait instead of running to the
  timeout.
- Keep the baseline behaviour (only a match that appears after the send counts) and the `.screen` evidence file.
- Existing tests keep passing; members run unrestricted, so nothing here may depend on the member's cooperation.
- Stacked on `feat/2978-herdr-app-parity` (#2990), which edits the same file.

## Open questions

- Exact Codex error line shapes: the `■` prefix is confirmed in the 0.169 binary for interrupt, copy and export
  errors; the spec will confirm it for usage-limit, capacity and stream errors (source or a captured screen) before
  relying on it, and keep a fallback if a provider error has no prefix.
