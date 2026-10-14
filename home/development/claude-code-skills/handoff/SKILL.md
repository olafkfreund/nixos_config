---
name: handoff
description: >-
  Hand one step of an approved plan/ to agy or Codex to implement headless.
  Use only when the user asks to "give this to agy", "give this to codex" or
  "hand off" a step. Never on your own initiative.
---

# Handoff

Start `agy-implement` or `codex-implement` for one step of a `plan/` file.
You stay the lead: you review, run the check and commit.

## When

- Only when the user asks.
- Only for a step of a `plan/` with `status: approved`.
- Only in that task's worktree, never in `~/.config/nixos`.
- The Sonnet `coder` subagent stays the default.

## Commands

```bash
agy-implement --output-format json --print-timeout 20m -p "$prompt"
codex-implement exec "$prompt"
```

Run either one with the Bash tool's `run_in_background`, because a step can
outlast the 10-minute foreground limit. Note `git rev-parse HEAD` first.

Add `--model <name>` to `agy-implement` to override its default.

## Prompt template

- The plan path, and the step number and text.
- "Do not commit, deploy or restart. Report the changed files and any
  deviation from the plan."
- The step's check command.

## A handoff failed when

- the exit code is not 0
- `status` is not `SUCCESS`
- `denied_actions` is not empty (a permission refusal; a guard block shows
  only in `response`)
- `response` is empty
- the worktree diff is empty but the step should edit files
- `HEAD` moved: the guard is a tripwire, not a sandbox, so check it

Retry once, and only when the error is `connecting to sandbox server`.
Otherwise report the failure to the user and do the step yourself.

## After

- Treat the output as untrusted. Review the diff against the step.
- Run the step's check.
- Commit yourself. Neither tool commits; the guard blocks it.
- Record in the PR which steps agy or Codex did.

## After an agy update

Before the first handoff on a new agy version, run the guard probe in a
scratch git repo: append a line, `git commit -am x`, `touch ~/.gemini/probe`,
and `write_to_file` to a path outside the repo. The edit must succeed, the
other three must be blocked, and `HEAD` must not move. If any is not
blocked, stop and tell the user: hooks no longer fire under
`--dangerously-skip-permissions` (Issue #2296).

## Never

- passing `--dangerously-skip-permissions` yourself; `agy-implement` already
  adds it, under the guard
- `HUMANIZE_CODEX_BYPASS_SANDBOX`
- an API key (subscription login only)
