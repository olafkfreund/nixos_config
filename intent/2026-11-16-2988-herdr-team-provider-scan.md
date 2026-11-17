---
status: approved
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

A phrase counts only on a line with a verified provider-error shape, not anywhere on screen:

- Codex: the line starts with `■` (Codex 0.169 renders terminal errors as `format!("■ {message}")`, the path its
  usage-limit, capacity, stream and rate-limit failures take once retries are exhausted);
- agy: the line starts with `agy error:` (printed by `agy-acp-member.py` for prompt errors).

Incidental matches (code, logs or docs a member reads or prints) no longer end the wait. The `<n>.screen` evidence
file uses the same rule. The usage-limit, capacity, stream-disconnect and rate-limit errors above are still caught,
and the phrase list gains Codex's two missing capacity messages (`Policy-restricted capacity is unavailable`,
`Flex capacity unavailable`).

Accepted limitation: a member that prints an exact error line on purpose (for example agy quoting a line that
starts with `agy error:`) can still trigger it. Screen scanning cannot tell origin; this is the same trust level as
today, minus the accidental matches.

## Affected users and systems

- `home/development/herdr-team.sh` and `home/development/herdr-team-test.sh` (the `ask` loop and `perr_count`).
- Every herdr-team task on p620 and razer (TUI and herdr-app backends); the `second-opinion` and `handoff` skills
  that rely on `ask`.

## Constraints

- No regression for the listed terminal errors: each must still end the wait instead of running to the timeout.
  The count-based baseline (only matches that appear after the send count) stays as it is, including its existing
  blind spot when an old line scrolls off as a new one appears; fixing that is out of scope.
- Keep the `.screen` evidence file. Existing tests keep their guarantees; fixtures that use unprefixed error text
  change to the verified shapes, and a new test shows an unprefixed phrase no longer triggers.
- Members run unrestricted, so nothing here may depend on the member's cooperation.
- Stacked on `feat/2978-herdr-app-parity` (#2990), which edits the same file.

## Open questions

- Transient retries: while Codex retries (HTTP 429, a dropped stream) it shows the status in its status indicator,
  without `■`, so `ask` would keep waiting until the retries succeed or fail with a terminal `■` error.
  Recommendation: keep waiting, since a retry that succeeds is not a failure and a final failure is still caught.
