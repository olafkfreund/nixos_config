---
status: draft
issue: 2031
author: olafkfreund
---

# Intent: Claude Code reads AGENTS.md natively

Follows `intent/2026-09-15-1832-agents-md-parity.md`.

## Problem

# 1832 made `AGENTS.md` the single source of the repo rules. At the time
Claude Code only read `CLAUDE.md`, so `CLAUDE.md` stayed behind as a shim:
`@AGENTS.md` plus two Claude-only sections (the bus-hook note and
"Second opinions").

Claude Code 2.1.282 now loads `AGENTS.md` itself. The binary's
`instructionFiles` option defaults to `claude-md-or-agents-md`: "a project
with no CLAUDE.md of its own gets its AGENTS.md files instead, loaded exactly
where and how CLAUDE.md would be". No settings file in this repo or on the
hosts sets the option. Because our `CLAUDE.md` exists, the native path never
runs. The shim is now the one Claude-specific layer the repo no longer needs.

References around the repo still treat `CLAUDE.md` as the conventions file:

- `catalog-info.yaml` (Backstage link titled "Agent conventions (CLAUDE.md)")
- `docs/NIXOS-ANTI-PATTERNS.md` and `docs/guides/GITHUB-WORKFLOW.md` (links)
- `docs/applications/sunshine.md`, `modules/desktop/sunshine.nix` and
  `modules/common/networking.nix` (prose saying the rules live in `CLAUDE.md`)
- `.claude/agents/nix-anti-pattern-auditor.md` (tells the agent to read it)
- `.claude/commands/nix-help.md`, `docs/tooling/CLAUDE-CODE-OPTIMIZATION.md`
  and `.claude/CLAUDE-CODE-2.1.2-UPDATES.md`, which point at a
  `.claude/CLAUDE.md` that does not exist at all

## Proposed outcome

- The repo has one agent instructions file, `AGENTS.md`, and Claude Code
  loads it natively, with no Claude-specific wrapper.
- The two Claude-only rules still reach Claude: prose goes through
  `--body-file` because of the bus hook, and other models are consulted only
  on request.
- Every in-repo pointer to the repo's conventions names `AGENTS.md`, and none
  points at a file that does not exist.

## Affected users and systems

- Agents: Claude Code on p620, razer and p510. Codex and Antigravity see a
  change only if Claude-only text moves into `AGENTS.md`.
- Files: `CLAUDE.md`, `AGENTS.md`, and the reference files listed above.
- Nothing is built or deployed. The change is to repo files only, read when a
  session starts.

## Constraints

- Claude must not lose any rule it sees today. Before `CLAUDE.md` is removed,
  a fresh `claude -p` session in the repo must answer from `AGENTS.md`.
- Out of scope, because native loading only covers **project** files:
  - the managed policy `/etc/claude-code/CLAUDE.md`
    (`modules/programs/claude-code-managed-claude.md`)
  - the user global `~/.claude/CLAUDE.md`
  - the `!CLAUDE.md` Syncthing allow-list entry (`home/syncthing-stignore.nix`,
    which is about `~/.claude/`)
  - the nixarchy repo's `CLAUDE.md` mentioned in `modules/services/nixarchy-runner.nix`
- The intent, spec and plan history files are records and stay as written.

## Open questions

1. **Where do the two Claude-only sections go?**
   - (a) A short "Claude Code" section in `AGENTS.md`, which Codex and
     Antigravity would also read. The second-opinion rule is about them anyway.
   - (b) `.claude/rules/`, if Claude Code auto-loads it (to be verified in
     the spec).
   - (c) Keep `CLAUDE.md` as the shim and fix only the references. Native
     loading stays unused.
2. **Should `instructionFiles` be pinned** to `claude-md-or-agents-md` in
   `.claude/settings.json`, so a future change to the default can't silently
   drop the repo rules? Or do we trust the default?
3. **Stale docs** that describe a `.claude/CLAUDE.md` that never existed
   (`docs/tooling/CLAUDE-CODE-OPTIMIZATION.md`,
   `.claude/CLAUDE-CODE-2.1.2-UPDATES.md`): repoint the links, or delete the
   files as obsolete?
4. **The nested `home/development/claude-code-skills/cosmic-ui-design-skill/AGENTS.md`**:
   in native mode, nested `AGENTS.md` files load when Claude works in that
   directory. Accept that, or exclude it?
