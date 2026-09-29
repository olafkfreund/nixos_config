---
status: approved
issue: 2087
author: olafkfreund
---

# Intent: Antigravity may write code for approved plans

## Problem

Two issues have split coding work by model:

- **Claude (#2079).** Opus plans and reviews; a Sonnet `coder` subagent
  implements.
- **Codex (#2081).** A Codex session plans on `gpt-6-astra`, and implements
  on `gpt-6-sol` through `codex-implement`.

In both, the shared `modules/programs/claude-coder-guard.sh` blocks
commits, deploys, restarts, garbage collection and reboots, and a live probe
has proven it for each tool.

Antigravity is still read-only by rule. `AGENTS.md` bans
`agy --mode accept-edits` against this tree, and the `second-opinion` skill
keeps agy in `--mode plan`. The #2081 spec deferred Antigravity "once Codex
has run a few real tasks". You have chosen to do it now.

The installed `agy` 1.2.12 has what the split needs:

- `--mode accept-edits` (write access) and `--mode plan` (read-only);
- `--model` for the session model, and `--effort`;
- `--sandbox` (terminal restrictions);
- `PreToolUse` hooks configured through `hooks.json`, according to
  strings in the binary. Nothing here has confirmed that they run yet.

`agy models` lists Gemini 3.8, 3.7 and 3.6 Flash (high, medium and low),
Gemini 3.1 Pro (high and low), Claude Sonnet 4.6, Claude Opus 4.6 and
GPT-OSS 120B.

## Proposed outcome

- **An `agy` session you start may write code** for an approved `plan/`, in
  a task worktree, through a single entry point, `agy-implement`. That runs
  `--mode accept-edits` on the implementation model and turns the guard on.
- **Delegated agy stays read-only.** When another agent calls it
  (`second-opinion`), it stays in `--mode plan`.
- **Model by stage**, as for Codex:
  - a strong model writes intent, spec and plan, and decides revisions;
  - a cheaper model implements;
  - the strong model reviews.

  The spec picks the models from `agy models`.
- **The same guard, the same limits.** The shared guard enforces them:
  - no deploys, restarts, garbage collection or reboots;
  - no commits;
  - no branch changes in the shared `~/.config/nixos` checkout.
- **Proven before use.** A live probe, as for Codex, must show:
  - `agy-implement` is blocked with the guard's own message, not by a
    sandbox or permission error;
  - plain `agy` is unaffected.
- **The rules say the same thing everywhere.** `AGENTS.md`, the
  `second-opinion` skill and the Antigravity global rules
  (`~/.gemini/AGENTS.md`) all describe delegated agy versus
  `agy-implement`.

## Affected users and systems

- **Rules.** `AGENTS.md` ("Delegating to other models"), the
  `second-opinion` skill, and `home/development/agent-rules.nix` (the
  Antigravity half, which builds `~/.gemini/AGENTS.md`).
- **agy configuration.** `home/development/antigravity-config.nix` gets the
  wrapper, any profile or settings, and the hook registration.
- **Shared guard.** It is reused as-is. Only its wrapper and registration
  are new.
- **Hosts.** p620 and razer. p510 only with your approval.

## Constraints

- **Enforced, not trusted to memory.** If agy's user hooks need a trust or
  approval step that silently skips them (as Codex's do), the guard must go
  in whatever managed or trusted layer agy offers. If agy offers none, the
  wrapper must fail closed rather than open. The Codex probe shows why:
  a guard that isn't trusted does nothing and says nothing.
- **Syncthing.** `~/.gemini` is synced through an allowlist
  (`home/syncthing-stignore.nix`). Nothing may be placed there as a Nix
  store symlink on a synced path. New files go on an unsynced path, or are
  written as real files.
- **No `--dangerously-skip-permissions`.** It is the agy counterpart of
  `HUMANIZE_CODEX_BYPASS_SANDBOX`, and it stays banned.
- **Subscription login only** (#1831).
- **One implementer per task, in its own worktree.**

## Open questions

1. **Models.** Which model plans and reviews: Gemini 3.1 Pro (high), or
   Claude Opus 4.6 through agy? Which implements: Gemini 3.8 Flash (medium
   or high)? The proposal is Gemini 3.1 Pro (high) for plan and review, and
   Gemini 3.8 Flash (medium) for implementation, keeping agy on Google's
   models.
2. **Hook trust.** Does agy run user `hooks.json` hooks without a trust
   step, and does it have a managed layer like Codex's
   `/etc/codex/requirements.toml`? The spec must settle this from agy's own
   documentation or a probe, not from assumptions.
3. **Sandbox.** Should `agy-implement` add `--sandbox`, as `codex-implement`
   runs `workspace-write`, or can the guard alone stand behind
   `accept-edits`?
4. **Commits.** Does agy commit on the task branch, or leave commits to
   you? The proposal is no commits, the same as Claude's coder and Codex.
