---
status: draft
issue: 3126
author: olafkfreund
---

# Intent: graphify strict project hooks for this repo

## Problem

Since #3122 (PR #3123) graphify is installed, but agents in this repo still
reach for grep and Read first. The owner asked for
`graphify install --project --strict` here, landed through a PR.

## Proposed outcome

In Claude Code sessions in this repo, where a local `graphify-out/graph.json`
exists:

- The first Read or Glob of a file the graph indexes is denied once per
  session. A `graphify query` in the last 30 minutes avoids the deny, and the
  retry is allowed.
- grep/rg searches get a nudge toward the graph.
- No hook ever returns `allow`, so permission prompts and the managed bus
  guard are unaffected.

Codex and agy get the same guidance as text in `AGENTS.md`.

## Affected users and systems

Agents working in this repo on p620 and razer. On p510 (no graphify) nothing
changes.

## Constraints

- The hooks must do nothing where `graphify` isn't installed (p510). The repo's
  `.claude/settings.json` is shared by every checkout.
- Don't commit a second copy of the skill. The user-level skill is
  Nix-managed (#3122).
- `graphify-out/` stays local and gitignored. A fresh worktree has no graph,
  so the hooks stay silent there until one is built.
- graphify can't parse `.nix`, so the hooks only gate sh/py/lua/js and docs
  files. That's expected.

## Open questions

None. The owner chose "~/.config/nixos via PR" with `--strict`.
