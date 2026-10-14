---
status: draft
issue: 2296
author: olafkfreund
---

# Intent: agy-implement runs with --dangerously-skip-permissions under the guard

Follows `intent/2026-10-14-2291-agy-headless-handoff.md`, which this
reverses on one point: that intent banned `--dangerously-skip-permissions`.

## Problem

Since #2295, `agy-implement` builds a per-run shadow home so it can carry a
`command(*)` allow rule that plain agy never sees.

- The shadow home works, but it is about 30 lines of shell with real
  edge cases: MCP children recreate caches after cleanup, the wrapper needs
  fail-closed checks, and state that agy rewrites by rename is lost.
- The user wants the coder to run with `--dangerously-skip-permissions`
  instead.

A probe on p620 (agy 1.3.4, 2026-10-14) shows the flag skips only the
permission prompts. PreToolUse hooks still run:

- The edit ran, with no `denied_actions`.
- `git commit` was blocked by the coder guard, and `HEAD` did not move.
- `touch ~/.gemini/...` was refused by the adapter's `.gemini` fence.

Separately, razer's agy is signed in with the freundcloud.com account (no AI
Ultra). That is why it lists no Gemini 4 Argon models, while p620 uses the
gmail.com Ultra account.

## Proposed outcome

- **The wrapper.** `agy-implement` runs
  `AGY_CODER=1 agy --mode accept-edits --sandbox --dangerously-skip-permissions`
  with the same two fail-closed guard checks. The shadow home goes away.
- **The flag's scope.** It is allowed only inside `agy-implement`, which is
  only reachable through the guard. It stays banned for plain agy, for
  `--mode plan`, and for Codex (`HUMANIZE_CODEX_BYPASS_SANDBOX`, Codex's
  bypass flag).
- **Rules.** `AGENTS.md` and the `handoff` skill say exactly that.
- **razer.** Once the user signs agy in with the Ultra account, razer runs
  the same default model as p620, with no `--model` workaround.
- **Proof.** On p620 and razer: the edit runs, the commit is blocked, the
  `~/.gemini` write is blocked, and plain `agy` is still auto-denied.

## Affected users and systems

- `home/development/antigravity-config.nix` (the `agy-implement` wrapper)
- `AGENTS.md`, the `handoff` skill and `agy-standards.md`
- p620 and razer. p510 only with your approval.

## Constraints

- **The guard registration checks stay.** The wrapper refuses to start
  unless the guard is installed and registered. Under the flag, the guard is
  the only barrier.
- **Deny by default.** The adapter keeps denying every tool outside its
  allow-list, and keeps its `.gemini` fence.
- **The sandbox stays on.** `--sandbox` is kept.
- **Subscription login only** (#1831).

## Open questions

1. **Signing razer in.** The OAuth login is interactive, so you need to sign
   razer's agy in with the gmail.com Ultra account: run `agy` on razer, log
   out, and log in again. Is that fine, or should razer keep its own
   account and the skill keep the `--model` workaround?
