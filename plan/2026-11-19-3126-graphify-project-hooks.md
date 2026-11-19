---
status: approved
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
- The rules text goes into `AGENTS.md`, after "Build / test / deploy".
- No skill copy, no CLAUDE.md, no backup file.

## Steps

1. `.claude/settings.json`: add `hooks.PreToolUse` beside the existing
   `PostToolUse`, keeping that untouched. It uses the same nested shape as
   `PostToolUse`:

   ```json
   "PreToolUse": [
     { "matcher": "Bash|Grep", "hooks": [ { "type": "command", "timeout": 10,
       "command": "command -v graphify >/dev/null 2>&1 || exit 0; exec graphify hook-guard search" } ] },
     { "matcher": "Read|Glob", "hooks": [ { "type": "command", "timeout": 10,
       "command": "command -v graphify >/dev/null 2>&1 || exit 0; exec graphify hook-guard read --strict" } ] }
   ]
   ```

   → verify with the `jq` checks in Tests.
   Traps: don't reorder or reformat `PostToolUse`.
2. `AGENTS.md`: add a short `## graphify` section after "Build / test / deploy".
   It covers:
   - when `graphify-out/graph.json` exists, run `graphify query` before grep
     or Read;
   - `path` / `explain`;
   - read raw files only for the lines already located;
   - after code changes, run `graphify update .` (when graphify is installed);
   - .nix isn't indexed;
   - the strict hook, and `GRAPHIFY_HOOK_STRICT=0` exported before starting
     Claude Code.

   → verify: markdownlint.
3. Lead: run the Tests replay, then commit, PR, review and merge. This is not a
   host switch: the shared checkout picks it up on its next pull. Then run the
   live `claude -p` check from the spec.

## Tests

```bash
jq -e '.hooks.PreToolUse | length == 2
  and all(.[]; .hooks[0].type == "command" and .hooks[0].timeout == 10)
  and (map(.matcher) == ["Bash|Grep","Read|Glob"])' .claude/settings.json
diff <(git show origin/main:.claude/settings.json | jq .hooks.PostToolUse) \
     <(jq .hooks.PostToolUse .claude/settings.json)
nix run nixpkgs#markdownlint-cli -- -c .markdownlint.json AGENTS.md
graphify extract . --code-only   # local graph for the replay
```

Replay each hook command from `.claude/settings.json` with `sh -c`. Feed it a
PreToolUse JSON (`session_id`, `tool_name`, `tool_input`, `cwd`) on stdin and
expect:

- Read of `scripts/compare-guards.py`: deny the first time, then allowed.
- Read of `flake.nix`: no output.
- Bash `git status`: no output. Bash `grep -rn x scripts`: `additionalContext`
  only.
- With `PATH=/usr/bin:/bin`: rc 0 and no output.
- No output anywhere contains `"allow"`.

## Rollback

- Revert the PR: removes the hooks and the AGENTS.md section.
- Or export `GRAPHIFY_HOOK_STRICT=0` before starting Claude Code: keeps the
  soft nudges and drops only the deny.
