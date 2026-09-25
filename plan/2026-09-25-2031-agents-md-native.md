---
status: approved
issue: 2031
spec: spec/2026-09-25-2031-agents-md-native.md
---

# Plan: Claude Code reads AGENTS.md natively

Branch `docs/2031-agents-md-native`, in the main checkout. Repo files only.
Nothing is built, deployed or restarted, so the bus announce rule does not
apply.

## Approved decisions

These are carried over from the spec.

**D1. `CLAUDE.md` is deleted.** Claude Code 2.1.282 loads `AGENTS.md`
natively when a project has no `CLAUDE.md`. This was verified with tools
disallowed in a scratch repo. `AGENTS.md` gets a new last section, with this
exact text:

```markdown
## Claude Code

- The bus rule above is enforced for you by a PreToolUse hook
  (`modules/programs/claude-code-managed.nix`). It matches words in command
  text, so write prose (commit bodies, issue comments) to a file and pass it
  with `--body-file`.
- Consult other models (Codex, Antigravity) only when the user asks, through
  the `second-opinion` skill. Never on your own initiative.
```

The other two "Second opinions" bullets are already covered by
**Delegating to other models** and are not copied.

**D2. References are repointed** to `AGENTS.md`:

- `catalog-info.yaml:108-109`: the URL, and the title
  `Agent conventions (AGENTS.md)`
- `docs/NIXOS-ANTI-PATTERNS.md:1124`: the link text and URL
- `docs/guides/GITHUB-WORKFLOW.md:998`: the link text and URL
- `docs/applications/sunshine.md:59`
- `modules/desktop/sunshine.nix:24` (comment)
- `modules/common/networking.nix:51` (comment)
- `.claude/agents/nix-anti-pattern-auditor.md:42-43`: becomes
  "Repo-root `AGENTS.md` — repo conventions", and the `.claude/CLAUDE.md`
  mention is dropped
- `.claude/commands/nix-help.md:456, 540`: `.claude/CLAUDE.md` becomes
  `AGENTS.md`
- `.claude/skills/tailscale.md:1004`

The history files, `home/development/agent-rules/*`,
`home/syncthing-stignore.nix`, `modules/programs/claude-code-managed.nix`,
`modules/services/nixarchy-runner.nix` and
`docs/tooling/claude-code-update-2.0.54.md` are left alone.

**D3. `instructionFiles` is not pinned.** It had no effect as a settings key.
Test T2 is the guard.

**D4. Stale docs are deleted:**

- `docs/tooling/CLAUDE-CODE-OPTIMIZATION.md`, along with its nav line in
  **both** `mkdocs.yml:207` and `mkdocs-full.yml:199`, and its two-line entry
  at `docs/README.md:120-121`
- `.claude/CLAUDE-CODE-2.1.2-UPDATES.md`

**D5. The nested cosmic-ui `AGENTS.md` stays** as it is.

**Lint baseline (2026-09-25):** every touched `.md` file is clean except
`.claude/commands/nix-help.md`. It has one MD024 error, a duplicate
`### Quick Fix` heading at lines 268 and 461. The pre-push hook lints whole
files, so line 461 becomes `### Emergency Quick Fix` in the same commit.

## Steps

1. **`AGENTS.md`:** append the D1 section. **`CLAUDE.md`:** `git rm`.
   → verify: `markdownlint AGENTS.md` is clean, `test ! -e CLAUDE.md`, and
   `grep -c '^## Claude Code' AGENTS.md` returns `1`.
2. **T2 gate, before anything else is touched.** Run the two `claude -p`
   questions from the Tests table in the repo root.
   → verify: they answer `p510` and mention `--body-file`. If either fails,
   **stop**: restore `CLAUDE.md` (`git restore --staged --worktree CLAUDE.md`),
   report, and do not continue.
3. **References (D2):** edit the nine files.
   **`nix-help.md:461`:** rename the heading to `### Emergency Quick Fix`.
   → verify: markdownlint is clean on each touched `.md`, and
   `yamllint -d relaxed catalog-info.yaml` shows no new errors.
4. **Stale docs (D4):** `git rm` both files, and remove the nav line in both
   mkdocs files and the two `docs/README.md` lines.
   → verify: `git grep -n CLAUDE-CODE-OPTIMIZATION -- ':!intent' ':!spec' ':!plan'`
   returns nothing, and markdownlint on `docs/README.md` is clean.
5. **Whole check:** run T1, T3, T4 and T5.
6. **Commit** 1–4 as
   `docs(agents): let Claude Code read AGENTS.md natively, retire CLAUDE.md (#2031)`
   (the message goes through `-F -` with a quoted heredoc).
   → verify: the pre-commit hooks pass.
7. **Push** (this runs the pre-push markdownlint and yamllint), then open a PR
   that links the intent, spec and plan, with `Closes #2031`. Merging is
   left to the user.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | `test ! -e CLAUDE.md`; `git grep -n 'CLAUDE\.md' -- ':!intent' ':!spec' ':!plan'` | Only the lines left alone in D2 (the global files, stignore, managed module, nixarchy-runner, the 2.0.54 checklist) |
| T2 | `echo "Which host must never be built or deployed without asking? Hostname only. Do not use tools." \| claude -p --disallowedTools Read Bash Grep Glob Agent`, then the same with "What must you pass prose through because of the PreToolUse hook? Do not use tools." | `p510`; mentions `--body-file` |
| T3 | `git grep -n '\.claude/CLAUDE\.md' -- ':!intent' ':!spec' ':!plan'` | Nothing |
| T4 | `grep -n CLAUDE-CODE-OPTIMIZATION mkdocs.yml mkdocs-full.yml docs/README.md`; `mkdocs build --strict -f mkdocs-full.yml` if mkdocs is available | No match; the build does not complain about a missing nav file |
| T5 | `just check-syntax` | Pass |

## Deviations

- **T2 ran in a throwaway worktree at a scratchpad path**, not the repo
  root. The project auto-memory (`~/.claude/projects/<repo path>/memory/`)
  already mentions `p510` and `--body-file`, so a run in the checkout could
  answer from memory. In the worktree, with no memory for that path and tools
  disallowed, it answered `p510` and quoted the new section's `--body-file`
  sentence. `AGENTS.md` was the only possible source.
- **T3's regex also matches `~/.claude/CLAUDE.md`** in
  `home/development/agent-rules/codex-standards.md`. That is the user global
  file, which D2 leaves alone, so the single hit is expected.

## Rollback

- **Before merge:** close the PR, then `git switch main`. `CLAUDE.md` is
  still on `main`.
- **After merge:** `git revert` the step-6 commit. `CLAUDE.md` comes back,
  and the `@AGENTS.md` import resumes. `AGENTS.md` keeps working in either
  state, since the import deduplicates it.
- There is no host state to roll back.
