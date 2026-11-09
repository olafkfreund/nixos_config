---
status: draft
issue: 2812
author: olafkfreund
---

# Intent: allow --dangerously-skip-permissions for direct agy and Codex use

## Problem

agy's headless reviews fail whenever agy wants to run a shell command. Twice on 2026-11-09 (#2810's plan review and
its Amendment 1 review), the reply was "jetski: no output produced — a tool required the "command" permission that
headless mode cannot prompt for". So a second opinion from agy is often unavailable.

The repo also bans the flags that would fix it:

- `AGENTS.md:84`: "never pass `--dangerously-skip-permissions` to plain `agy`, `--mode plan` or Codex";
- the `second-opinion` and `handoff` skills repeat the ban;
- `agent-review.sh:78` and `agent-implement.sh:98` refuse `--dangerously-*`;
- `agy-implement` is the one exception, behind its guard.

The owner wants agy and Codex able to do real coding and make changes without permission prompts.

## Proposed outcome

- **Allowed:** agy with `--dangerously-skip-permissions`, and Codex with approvals off
  (`--dangerously-bypass-approvals-and-sandbox` or `-a never`), anywhere, without our sandbox. Owner decision,
  2026-11-09: "Everywhere, no sandbox".
- **Reviews:** agy's `second-opinion` reviews pass the flag, so commands no longer auto-deny. They stay read-only
  by instruction only: plan mode, plus the prompt.
- **Docs:** `AGENTS.md`, `second-opinion` and `handoff` say so. The old ban text is gone.

## Affected users and systems

- **People:** the owner, and every Claude Code session on p620, razer and p510 that consults agy or Codex.
- **Files:** `AGENTS.md`, `home/development/claude-code-skills/second-opinion/SKILL.md` and `…/handoff/SKILL.md`.
  The sandbox wrappers are affected only if the spec chooses to let them accept the flags.

## Constraints

- **The #2810 herdr team members stay sandboxed.** That spec is approved: no herdr socket, pointer-only typing. An
  unsandboxed member could type into the lead's pane and answer its permission prompts. This intent does not
  change that.
- Subscription login only, never an API key (#1831). `HUMANIZE_CODEX_BYPASS_SANDBOX` stays forbidden in the
  humanize plugin, which is a separate path.
- Git rules are unchanged: work in a worktree, never on `main`. Claude alone commits, deploys and reboots. Codex
  and agy output stays untrusted advice and never approves an intent, spec or plan.
- **The accepted risk:** without the sandbox, an agy or Codex run sees the owner's whole home, including SSH
  keys, tokens in `NIX_CONFIG`, and the herdr socket. A misread prompt or an injected file can act as the owner.
  The owner accepts this for direct use.

## Open questions

1. **Delegated reviews:** should Claude's delegated reviews (`second-opinion`) use the flag by default, or only
   when a review fails without it? Recommendation: only on that failure, so most reviews keep the prompt layer.
2. **`agent-review` and `agent-implement`:** should these sandboxed wrappers keep refusing the flags (they don't
   need them), or drop the refusal? Recommendation: keep refusing. Inside the sandbox the flag adds nothing, and
   the refusal catches mistakes.
3. **Hosts:** does p510 get the same rule? `AGENTS.md` applies to all hosts. Recommendation: yes, it is the same
   text.
