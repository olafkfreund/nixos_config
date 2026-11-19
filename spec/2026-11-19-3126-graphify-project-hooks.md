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
| `CLAUDE.md` "## graphify" rules section | Goes into `AGENTS.md` after "Build / test / deploy" (this repo has no CLAUDE.md; Claude, Codex and agy all read AGENTS.md, and Claude lists it as loaded project instructions). Shortened, with a .nix note. The line about a committed graph.json is dropped (it's gitignored). |
| `.claude/CLAUDE.md` + `.claude/skills/graphify/` | Dropped: they duplicate the Nix-managed user skill |
| `.claude/settings.json.graphify-bak` | Dropped |

Behaviour measured against a code-only graph of this repo (213 code files,
1511 nodes, 5s to build):

| Call | Result |
| --- | --- |
| Read of an indexed `.py`, first time | `permissionDecision: deny`, with a `graphify explain` hint |
| Same Read again | allowed, with `additionalContext` |
| `graphify query`, then Read in a new session | no deny |
| Read of a `.nix` file | silent pass |
| Bash `git` / `just` / `nix` / `cat` | silent pass |
| Bash `grep -rn` / `rg` | `additionalContext` nudge only |
| Grep or Glob on a directory | silent pass |
| No graph, or graphify not on PATH | rc 0, no output |

No output ever carries `permissionDecision: allow`. Cost is about 0.12s per
hooked tool call.

## Alternatives rejected

- Running upstream's installer as is: it duplicates the skill, adds a
  CLAUDE.md, and breaks on p510 (hook command not found).
- Without `--strict`: the owner chose strict.

## Risks

- About 0.12s added to each Bash/Grep/Read/Glob call in this repo.
- The strict deny is a one-time interruption per session. Escape hatch:
  export `GRAPHIFY_HOOK_STRICT=0` before starting Claude Code.
- A session started with graphify missing from PATH skips the guard silently.
  This is the price of the p510 no-op, and the live check below covers it.
- A graph that hasn't been rebuilt goes stale. `graphify update .` keeps it
  current.

## Verification

- `jq` checks the exact hook shape, and `PostToolUse` is unchanged against
  origin/main.
- The hook replays in the plan's Tests reproduce the table above.
- After merge, a headless `claude -p` in the shared checkout tries to read an
  indexed `.py` and hits the deny. That proves the real hook PATH resolves
  graphify.
- markdownlint passes on `AGENTS.md`.
