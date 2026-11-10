---
status: draft
issue: 2829
author: olafkfreund
---

# Intent: `herdr-team finish --verify`

## Problem

`herdr-team finish <task> implement|agy-implement` checks the graceful exit code, an unchanged `HEAD`, a non-empty diff,
nothing staged, and that the last `outcome` was `ok`. It never runs the step's own check. Every approved
`plan/` step names one: shellcheck, a test suite, a build.

So a step can "finish" green while its test fails. The lead finds out only after the implementer has quit and
its pane is gone, and then has to fix the step or start a new member that has none of the context.

## Proposed outcome

- `herdr-team finish <task> implement|agy-implement --verify '<cmd>' [--retries N]` (default 1, maximum 3).
  1. It runs the lead-supplied check in the task worktree before quitting the implementer.
  2. When the check fails, it sends the same live implementer one request with the command and the tail of its
     output, waits for the answer, and runs the check again, up to N times.
  3. Then the usual `finish` checks run.
- **A retry needs a counted answer.** If an answer is not `ok` (`timeout`, `agent_gone` and so on), retrying
  stops at once and that outcome is reported. A request left pending never lets a later check pass on an old
  `ok`.
- **The diff must be the implementer's.** "Non-empty diff" is judged on the implementer's changes, so files
  the check itself creates or changes (build output, caches) cannot turn an empty step green.
- **Every failure stays visible.** The JSON adds `verify: {cmd, exit, attempts, tail}`. A failing check gives
  `ok: false`, but it never hides the existing checks: a moved `HEAD`, staged changes, a bad exit or a non-`ok`
  last outcome are all reported alongside `verify_failed`. The implementer is still stopped, as on any failed
  `finish` today.
- Without `--verify`, `finish` behaves exactly as today.

## Affected users and systems

- `home/development/herdr-team.sh` (`finish`), `home/development/herdr-team-test.sh`,
  `docs/applications/herdr.md`.
- The `handoff` / `team` skills, which can pass the plan step's check.
- p620 and razer through Home Manager.

## Constraints

- The check is supplied by the lead (Claude), never by a member's reply.
- Today only `up` refuses the shared checkout and `main` (herdr-team.sh:223–228), and an unrestricted member
  could have switched branches since. So `finish --verify` checks again, before it runs anything, that the
  task worktree is not `~/.config/nixos` and is not on `main`. Then it runs the check with that worktree as its
  working directory.
  - A working directory is not a sandbox. The check is trusted because the lead wrote it, not because of where
    it runs.
- The check runs with the API key variables unset, like the members (#1831).
- The retry goes through the normal `ask` path: a request file and a pointer, a counted answer.
- The retry request reaches the member as a request file. It carries only the command and an output tail
  capped at a few KB.
- Members still never commit. `finish`'s `HEAD`-unchanged and nothing-staged checks run after the last retry.
- It builds on #2818 and lands after it.
- p510 is not touched.

## Open questions

- Should the check have its own timeout? Default: yes, `--verify-timeout`, 900 s.
- When the check is still failing after the retries, should the implementer be stopped, or left running so
  the lead can steer it in the pane? Default: stopped, as `finish` does today. The lead can `up` a new
  implementer, and the archive (#2818) keeps the exchange.
- Should a passing check be required before the implementer may quit on its own? Default: no. It applies only
  in `finish`, which is the lead's gate.
