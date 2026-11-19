---
status: draft
issue: 3126
intent: intent/2026-11-19-3126-graphify-project-hooks.md
---

# Spec: graphify strict project hooks for this repo

## Design

What `graphify install --project --strict` writes, checked in a scratch repo,
and what we keep:

| Upstream writes | Here |
| --- | --- |
| `.claude/settings.json` PreToolUse: `Bash\|Grep` → `graphify hook-guard search`, `Read\|Glob` → `graphify hook-guard read --strict` | Kept, wrapped in `command -v graphify >/dev/null 2>&1 \|\| exit 0; exec …` so it does nothing on p510 |
| `CLAUDE.md` "## graphify" rules section | Goes into `AGENTS.md` instead (this repo has no CLAUDE.md; all three agents read AGENTS.md). Shortened, with a .nix note. The line about a committed graph.json is dropped (it's gitignored). |
| `.claude/CLAUDE.md` + `.claude/skills/graphify/` | Dropped: they duplicate the Nix-managed user skill |
| `.claude/settings.json.graphify-bak` | Dropped |

Measured behaviour against a code-only graph of this repo (213 code files,
1511 nodes, 5s to build):

- First Read of an indexed `.py`: `permissionDecision: deny` with a
  `graphify explain` hint.
- Second Read: allowed, with `additionalContext`.
- `.nix` Read: silent pass.
- No graph: silent pass.
- Cost: about 0.12s per hooked tool call.

## Alternatives rejected

- Running upstream's installer as is: it duplicates the skill, adds a
  CLAUDE.md, and breaks on p510 (hook command not found).
- Without `--strict`: the owner chose strict.

## Risks

- About 0.12s added to each Bash/Grep/Read/Glob call in this repo.
- The strict deny is a one-time interruption per session. Escape hatch:
  `GRAPHIFY_HOOK_STRICT=0`.
- A graph that hasn't been rebuilt goes stale. upstream skips denial for a
  graph marked `needs_update`. `graphify update .` (or `graphify hook install`
  in the shared checkout) keeps it current.

## Verification

- `jq` validates `.claude/settings.json`; the existing PostToolUse hooks are
  unchanged.
- Hook replays on a worktree with a graph: deny, then allow; `.nix` passes.
- With graphify off PATH: exit 0 and no output.
- markdownlint passes on `AGENTS.md`.
