---
status: draft
issue: 3126
spec: spec/2026-11-19-3126-graphify-project-hooks.md
coders: {}   # two small edits: the lead writes them (below the hand-off threshold)
reviewers:
  - codex    # hook wiring and the p510 no-op guard
  - agy      # independent read of the diff against this plan
---

# Plan: graphify strict project hooks for this repo

Decisions (from the spec):

- Strict PreToolUse hooks in `.claude/settings.json`, each guarded by
  `command -v graphify`.
- The rules text goes into `AGENTS.md`.
- No skill copy, no CLAUDE.md, no backup file.

## Steps

1. `.claude/settings.json`: add `hooks.PreToolUse` next to the existing
   `PostToolUse`, keeping it untouched. Two entries, each `timeout: 10`:

   - `matcher: "Bash|Grep"`:
     `command -v graphify >/dev/null 2>&1 || exit 0; exec graphify hook-guard search`
   - `matcher: "Read|Glob"`:
     `command -v graphify >/dev/null 2>&1 || exit 0; exec graphify hook-guard read --strict`

   → verify: `jq -e '.hooks.PreToolUse | length == 2' .claude/settings.json`,
   and `.hooks.PostToolUse` is unchanged against origin/main.
2. `AGENTS.md`: add a short `## graphify` section after "Commands". It covers:
   query first when `graphify-out/graph.json` exists; `path`/`explain`; read
   raw files only for the located lines; `graphify update .` after code
   changes; .nix isn't indexed; the strict hook and `GRAPHIFY_HOOK_STRICT=0`.
   → verify: markdownlint.
3. Lead: replay the hooks against a worktree graph (deny, then allow; `.nix`
   passes; no graphify on PATH → exit 0 with no output). Commit, PR, review,
   merge. This is not a host switch: the shared checkout picks it up on its
   next pull.

## Tests

```bash
jq -e '.hooks.PreToolUse | length == 2' .claude/settings.json
nix run nixpkgs#markdownlint-cli -- -c .markdownlint.json AGENTS.md
# replay (see spec): deny, then allow, .nix silent; PATH without graphify → rc 0, no output
```

## Rollback

Revert the PR, or set `GRAPHIFY_HOOK_STRICT=0` to drop to soft nudges.
