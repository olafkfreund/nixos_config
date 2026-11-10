---
status: draft
issue: 2829
author: olafkfreund
---

# Intent: `herdr-team finish --verify`

## Problem

`herdr-team finish <task> implement` checks the graceful exit code, an unchanged `HEAD`, a non-empty diff,
nothing staged, and that the last `outcome` was `ok`. It never runs the step's own check. Every approved
`plan/` step names one: shellcheck, a test suite, a build.

So a step can "finish" green while its test fails. The lead finds out only after the implementer has quit and
its pane is gone, and then has to fix the step or start a new member that has none of the context.

## Proposed outcome

- `herdr-team finish <task> implement --verify '<cmd>' [--retries N]` (default 1, maximum 3).
  1. It runs the lead-supplied check in the task worktree before quitting the implementer.
  2. When the check fails, it sends the same live implementer one request with the command and the tail of its
     output, waits for the answer, and runs the check again, up to N times.
  3. Then the usual `finish` checks run.
- The JSON adds `verify: {cmd, exit, attempts, tail}`. If the check still fails, `ok` is false with
  `reason: "verify_failed"`, and the implementer is still stopped (as today on a failed `finish`).
- Without `--verify`, `finish` behaves exactly as today.

## Affected users and systems

- `home/development/herdr-team.sh` (`finish`), `home/development/herdr-team-test.sh`,
  `docs/applications/herdr.md`.
- The `handoff` / `team` skills, which can pass the plan step's check.
- p620 and razer through Home Manager.

## Constraints

- The check is supplied by the lead (Claude), never by a member's reply.
- It runs as the lead, in the task worktree only: `finish` already refuses `~/.config/nixos` and `main`.
- The retry goes through the normal `ask` path: a request file and a pointer, a counted answer.
- The retry request reaches the member as a request file. It carries only the command and an output tail
  capped at a few KB.
- Members still never commit. `finish`'s `HEAD`-unchanged and nothing-staged checks run after the last retry.
- It builds on #2818 and lands after it.
- p510 is not touched.

## Open questions

- Should the check have its own timeout? Default: yes, `--verify-timeout`, 900 s.
- Should a passing check be required before the implementer may quit on its own? Default: no. It applies only
  in `finish`, which is the lead's gate.
