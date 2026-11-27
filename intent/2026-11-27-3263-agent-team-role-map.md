---
status: approved
issue: 3263
author: olafkfreund
---

# Intent: One role map for Claude, Codex and agy models

## Problem

Which model plays which role is set in five unrelated places, and they disagree:

- Claude Code: `CLAUDE_CODE_SUBAGENT_MODEL = "sonnet"` in
  `modules/programs/claude-code-managed.nix`, `model: sonnet` in the coder
  agent, `model: haiku` in the Explore agent (`home/development/claude-code-agents.nix`).
- Codex: `implement.config.toml` pins `gpt-6-sol`, `review_model` is seeded
  as `gpt-6-astra` only when absent (`home/development/codex-cli.nix`), and
  herdr-team's review member starts plain `codex`, so it inherits the user's
  base model (Sol) instead of a reviewer model.
- agy: `agy-implement` hard-codes its worker model
  (`home/development/antigravity-config.nix`).

Changing "the cheap model" or "the strong model" means finding every copy,
and nothing keeps the three tools in step.

## Proposed outcome

- One data file names the model and effort for each role (manager, reviewer,
  worker, explorer) and each tool (Claude, Codex, agy), plus the subagent
  limits.
- Claude's subagent default, coder and Explore agents, Codex's implement and
  a new manager profile, Codex's review model, agy's worker, and herdr-team's
  review member all read it.
- The herdr-team Codex reviewer runs on the reviewer model.
- Token savings that need no policy change: the coder keeps a 1-hour prompt
  cache between SendMessage steps; Explore skips CLAUDE.md.

## Affected users and systems

- p620 and razer (Home Manager and the managed Claude/Codex settings); p510
  evaluates the same modules.
- Claude Code, Codex, agy, herdr-team.

## Constraints

- Subscription logins only; no API keys.
- Codex owns `~/.codex/config.toml`: edit only root keys in place; Nix owns
  profile files.
- Defaults that keep today's behaviour where today's is right.
- p510: no build or deploy without the owner.

## Open questions

None; the owner chose the role map on 2026-11-27 (Opus manager).
