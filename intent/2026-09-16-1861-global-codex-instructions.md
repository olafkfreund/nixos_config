---
status: draft
issue: 1861
author: olafkfreund
---

# Intent: global Claude standards for every Codex session

## Problem

The global Codex instructions introduced in #1832 include NixOS standards,
the short PARR protocol, and artifact approval gates, but do not include all
the instructions in the user's global `~/.claude/CLAUDE.md`. Its detailed
working protocol and Agent OS standards references therefore do not reach
new Codex sessions automatically.

## Proposed outcome

Every new local Codex session using the managed default Codex home receives
the applicable global Claude standards, regardless of its working repository.
The global `AGENTS.md` preserves existing NixOS standards and approval gates,
survives rebuilds, and has a version-controlled source. The current global
`~/.claude/CLAUDE.md` is the requested source, not this repository's file.

## Affected users and systems

- The user's Codex sessions on hosts importing `home/development/agent-rules.nix`.
- The managed `~/.codex/AGENTS.md` and its declarative source.
- Antigravity currently shares the generated instructions; its behavior must
  be considered explicitly during design.

## Constraints

- Preserve the meaning of the global Claude instructions while adapting
  Claude-specific commands and references to capabilities available in Codex.
- Preserve repository-specific overrides and existing artifact approval gates.
- Keep configuration declarative; do not overwrite a Home Manager store link.
- Do not read files outside the flake during pure evaluation.
- Avoid duplicate PARR text and conflicting sources of the same rule.
- Verify loading in a fresh Codex session outside this repository.
- Existing sessions may need restarting. Custom Codex homes and remote/cloud
  environments require their own installation; local configuration alone
  cannot configure those environments.
- No p510 build or deployment without explicit approval.

## Open questions

None for problem framing. Source ownership, synchronization with Claude, and
the effect on the shared Antigravity output will be resolved in the spec.
