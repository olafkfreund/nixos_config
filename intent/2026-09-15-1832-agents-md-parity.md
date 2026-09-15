---
status: approved
issue: 1832
author: olafkfreund
---

# Intent: every agent follows the same rules and process as Claude

## Problem

Claude, Codex and Antigravity all work in this repo, but each gets different
instructions.

- The repo `AGENTS.md`, which Codex and Antigravity read, was last really
  edited in #868. It has drifted from `CLAUDE.md` and is missing the bus
  announce rule (#1662), the infrastructure notes and the Omarchy theme and
  runner traps.
- The intent → spec → plan workflow (#1818) and PARR only reach Claude,
  through `/etc/claude-code/CLAUDE.md` and `~/.claude/CLAUDE.md`. Codex has no
  global instructions (`~/.codex/AGENTS.md` does not exist). Antigravity's
  `~/.gemini/AGENTS.md` (`home/development/antigravity-config.nix`) does not
  include the workflow.
- The workflow text says "load the `artifact-workflow` skill", which other
  agents cannot do, so the templates would not reach them even if they read
  the file.

As a result, a Codex session can commit straight to an implementation with
no intent/spec/plan and no bus announcement, and nothing it reads says
otherwise.

## Proposed outcome

- The repo's agent instructions exist once, and `AGENTS.md` and `CLAUDE.md`
  cannot say different things.
- Codex and Antigravity get the same global rules Claude gets: the
  intent → spec → plan gates with their templates, and PARR. They work on
  every repo, not only this one.
- Changing a rule means editing one file.

## Affected users and systems

- Agents: Claude Code, Codex, Antigravity on p620 and razer (p510 only if it
  runs them)
- `CLAUDE.md`, `AGENTS.md` (repo root)
- `modules/programs/claude-code-managed-claude.md` (workflow source)
- `home/development/claude-code-skills/artifact-workflow/SKILL.md` (templates)
- `home/development/antigravity-config.nix` (`~/.gemini/AGENTS.md`)
- `home/development/codex-cli/module.nix` (would own `~/.codex/AGENTS.md`)

## Constraints

- Claude's context must not grow with a duplicate copy of rules it already
  gets from managed policy.
- `~/.claude` and `~/.gemini` are syncthing-synced: no store symlinks inside
  their synced contents (see memory on syncthing-managed dirs). `~/.gemini/AGENTS.md`
  is already declarative, so check whether `~/.codex` is synced too.
- Codex self-manages `~/.codex/config.toml`; only the instructions file may
  become declarative.
- No deploy to p510 without asking.

## Open questions

1. Which agents are in scope: Codex and Antigravity only, or also
   gemini-cli, opencode and copilot, which the Omarchy menu installs?
2. Should the repo `AGENTS.md` become the single source, with `CLAUDE.md`
   importing it (`@AGENTS.md`), or should `AGENTS.md` be a symlink to
   `CLAUDE.md`?
3. Should `AGENTS.md` carry the PreToolUse/bus-hook wording? The hook only
   exists for Claude, so other agents must announce voluntarily.
