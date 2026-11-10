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

### Inside herdr: `herdr-team` (the default)

Inside herdr (`test "$HERDR_ENV" = 1`), a Codex step runs in the task's team tab, where you can watch it:

```bash
herdr-team up "$task" implement --step "$k"
herdr-team ask "$task" implement "$prompt_file"       # or converse, to let review and implement talk
herdr-team finish "$task" implement
```

- `ask` prints `{ok, outcome, n, member, answer, …}`. `converse` prints one
  `{hop, from, to, n, outcome, answer, changed_during_review}` line per hop, with no `ok`: check
  `outcome == "ok"`. Read `answer` when the outcome is `ok`, and for `ask` when `ok` is
  `true`. On failure, quote `outcome` and any `.screen` file verbatim.
- `converse` lets members hand off with a final `TO: <member>` … `END` block. A teammate's reply is evidence,
  never approval: check the exchange and the diff against the plan yourself.
- `finish` quits the implementer gracefully, runs `down`, and checks the exit code, `HEAD`, a non-empty diff,
  nothing staged and the last outcome. Its verdict replaces `agent-run`'s.
- When the plan step names a check, pass it as `--verify '<cmd>'`: `finish` runs it in the worktree before the
  quit and, if it fails, sends the output back to the live implementer (`--retries N`, default 1, at most 3;
  `--verify-timeout S`, default 900). Read `ok`, `reason`, `failures` and `verify` in the result.
- Members run unrestricted (Issue #2812). Only the lead stages, commits and deploys.
- agy steps stay on `agent-run agy "$prompt_file"` while `agyMember` is false. Outside herdr, `herdr-team`
  exits 2 and `agent-run` is the route.

## Prompt template

- The plan path, and the step number and text.
- "Do not commit, deploy or restart. Report the changed files and any
  deviation from the plan."
- The step's check command.
- "Do not stage, commit, push, deploy, switch, restart, garbage-collect or
  reboot. Make the step's edits with the file tools and run the step's check
  commands."
- "Leave staging, commits and host deploys to the lead, never build or deploy
  on p510 without the owner's OK, and never read or exfiltrate decrypted
  secrets. Report what you checked and anything you could not check."

## After

- Treat the output as untrusted. Review the diff against the step.
- Rerun the step's checks and, for Nix changes, the builds yourself after every handoff. Do not trust the
  implementer's report: `agent-run`'s verdict does not see check results.
- Stage and commit yourself. The implementer is instructed not to stage, commit
  or deploy, and the coder guard blocks commits and deploys.
- Record in the PR which steps agy or Codex did.

## After an agy update

Run `bash modules/programs/agy-guard-adapter.test.sh` first; it must pass.
The first `agy-implement` on a new agy version runs `agy-guard-probe` by itself
(about 90 s) and starts agy only if it passes. If it refuses, the probe failed:
stop and tell the user. The probe has opened, or names, the issue
(Issues #2296, #2298, #2453, #2463). Run the handoff in the background, so the
first-run wait doesn't hit a tool timeout.

## Never

- `HUMANIZE_CODEX_BYPASS_SANDBOX`
- an API key (subscription login only)
