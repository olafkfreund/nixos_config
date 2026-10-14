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

Add `--model <name>` to `agy-implement` to override its default. razer's agy
login has no Gemini 4 Argon, so there pass `--model gemini-3.8-flash-medium`.

## Prompt template

- The plan path, and the step number and text.
- "Do not commit, deploy or restart. Report the changed files and any
  deviation from the plan."
- The step's check command.

## A handoff failed when

- the exit code is not 0
- `status` is not `SUCCESS`
- `denied_actions` is not empty
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

## Never

- `--dangerously-skip-permissions`
- `HUMANIZE_CODEX_BYPASS_SANDBOX`
- an API key (subscription login only)
