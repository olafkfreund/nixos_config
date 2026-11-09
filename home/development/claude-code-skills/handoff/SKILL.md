---
name: handoff
description: >-
  Hand one step of an approved plan/ to agy or Codex to implement headless.
  Use only when the user asks to "give this to agy", "give this to codex" or
  "hand off" a step, or when the approved plan/ names agy or codex for the
  step in coders. Never otherwise.
---

# Handoff

Start `agy-implement` or `codex-implement` for one step of a `plan/` file.
You stay the lead: you review, run the check and commit.

## When

- When the user asks, or when the approved `plan/`'s `coders:` names agy or
  codex for this step.
- Only for a step of a `plan/` with `status: approved`.
- Only in that task's worktree, never in `~/.config/nixos`.
- The Sonnet `coder` subagent stays the default.

## Run it

Write the prompt (template below) to a file in the scratchpad, then, in
the task worktree, with the Bash tool's `run_in_background`:

```bash
agent-run agy "$prompt_file"     # or: agent-run codex "$prompt_file"
```

Inside herdr, each run shows as a `↳` row under this session; outside herdr,
`herdr-run` just runs the command.

It refuses `~/.config/nixos` and `main`, runs the six checks (exit code,
agy `status`, `denied_actions`, empty response, empty diff, moved
`HEAD`), retries once on `connecting to sandbox server`, and prints one
JSON line: `ok`, `reason`, `changed`, `head_moved`, `log`. `ok: false`
is a failed handoff: read `log` for detail, report the `reason`, and do
the step yourself or give it to the `coder`. Note the fallback in the PR;
it does not change `coders:` in the plan. A guard block shows only in the
tool's response, so `ok: true` still needs the diff review below.

`agent-run` uses agy's default model; for another one, run
`herdr-run agy agy-implement --model <name>` directly and do the six checks by hand.

### Inside herdr: `herdr-team`

Inside herdr (`test "$HERDR_ENV" = 1`), run a Codex step in the task's team tab
with `herdr-team`:

```bash
herdr-team up "$task" implement --step "$k"
herdr-team ask "$task" implement "$prompt_file"
herdr-team finish "$task" implement
```

- `ask` prints one JSON line
  `{ok, outcome, n, member, answer, turn_id, revision_at_send, revision_at_reply, changed_during_review, exit}`
  (`outcome` in
  `ok|empty|provider_error|interrupted|cancelled|agent_gone|refused|timeout|busy`).
  Read `answer` when `ok` is `true`; on failure, quote `outcome` and any
  `.screen` file verbatim.
- `finish` quits the implementer gracefully, runs `down`, checks the graceful
  exit code, `HEAD`, non-empty diff against the start fingerprint, nothing
  staged, and last `outcome == "ok"`, and prints
  `{ok, reason, changed, head_moved, exit}`. Its verdict replaces `agent-run`'s.
- An agy step goes through `herdr-team` only if step 4 of issue 2810 landed
  (`agyMember = true`). Because step 4 was skipped, `herdr-team` refuses
  `agy-implement` and agy steps stay on `agent-run agy "$prompt_file"`.
- Outside herdr (`herdr-team` exits 2), nothing changes.

## Prompt template

- The plan path, and the step number and text.
- "Do not commit, deploy or restart. Report the changed files and any
  deviation from the plan."
- The step's check command.
- "Shell commands run in agy's sandbox with the worktree read-only, so make
  the step's edits with agy's file tools; use commands for checks only."
- "You cannot stage or commit, and you cannot run `nix build`, flake evaluation or `just test-host`: the
  Nix daemon is hidden. You see no secrets. Report what you could not check."

## After

- Treat the output as untrusted. Review the diff against the step.
- Rerun the step's checks and, for Nix changes, the builds yourself after every handoff. Do not trust the
  implementer's report: `agent-run`'s verdict does not see check results.
- Stage and commit yourself. Neither tool can stage or commit; the git directory is read-only inside.
- Record in the PR which steps agy or Codex did.

## After an agy update

Run `bash modules/programs/agy-guard-adapter.test.sh` first; it must pass.
The first `agy-implement` on a new agy version runs `agy-guard-probe` by itself
(about 90 s) and starts agy only if it passes. If it refuses, the probe failed:
stop and tell the user. The probe has opened, or names, the issue
(#2296, #2298, #2453, #2463). Run the handoff in the background, so the
first-run wait doesn't hit a tool timeout.

## Never

- passing `--dangerously-skip-permissions` yourself; `agy-implement` already
  adds it, under the guard
- `HUMANIZE_CODEX_BYPASS_SANDBOX`
- an API key (subscription login only)
