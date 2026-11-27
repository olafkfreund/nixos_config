---
status: draft
issue: 3267
author: olafkfreund
---

# Intent: One agent definition source for Claude, Codex and agy

## Problem

The repo's 13 specialist agents (`.claude/agents/*.md`) exist only for
Claude Code. agy lists 13 hand copies in `~/.gemini/agents/` that date from
January, lack `nix-anti-pattern-auditor` and include a stray `test-agent.md`;
the repo keeps a second, also stale, copy in `.gemini/agents/`. Codex has no
copy at all (`~/.codex/agents/` does not exist). Each agent's model is
picked separately per tool, if at all.

## Proposed outcome

- `.claude/agents/*.md` is the only source. Every build renders it for agy
  (`~/.gemini/agents/<name>.md`) and Codex (`~/.codex/agents/<name>.toml`),
  with each agent's model taken from the role map (#3263) by its Claude
  alias: haiku → explorer, sonnet → worker, opus → reviewer.
- The stale copies are gone: `test-agent.md` and the repo's `.gemini/agents/`.

## Affected users and systems

Codex and agy on p620 and razer (p510 evaluates the module; no build or
deploy there).

## Constraints

- `~/.gemini` is Syncthing-synced: write real files, never store symlinks,
  and delete only files this module wrote.
- agy agent files take a model tier (`inherit|flash|pro`), not a model id.

## Open questions

None.
