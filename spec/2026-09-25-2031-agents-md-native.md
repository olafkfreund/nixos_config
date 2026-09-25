---
status: draft
issue: 2031
intent: intent/2026-09-25-2031-agents-md-native.md
---

# Spec: Claude Code reads AGENTS.md natively

The intent was approved on 2026-09-25 without answers to its open questions,
so the defaults recommended with it are the decisions. The approver can
overrule any of them here.

| # | Question | Decision |
| --- | --- | --- |
| 1 | Where the Claude-only sections go | (a) A `## Claude Code` section in `AGENTS.md` |
| 2 | Pin `instructionFiles` | **Dropped.** The settings key could not be found (see Design §3). A test replaces it |
| 3 | Stale docs about `.claude/CLAUDE.md` | Delete |
| 4 | Nested `AGENTS.md` in the cosmic-ui skill folder | Accept |

## Design

### 1. `CLAUDE.md` is deleted, and its content moves into `AGENTS.md`

Claude Code 2.1.282 loads `AGENTS.md` natively when a project has no
`CLAUDE.md`. This was tested on 2026-09-25 in a scratch git repo that held
only an `AGENTS.md` with a codeword. `claude -p` was run with Read, Bash,
Grep, Glob and Agent disallowed and the prompt on stdin, and it returned the
codeword. The file therefore came from the context, not from a tool call.

- `git rm CLAUDE.md`.
- `AGENTS.md` gets a new last section with the two Claude-only blocks from
  today's `CLAUDE.md`. Their wording stays the same, except that "in
  AGENTS.md" becomes "above", since the text now lives in `AGENTS.md`:

  ```markdown
  ## Claude Code

  - The bus rule above is enforced for you by a PreToolUse hook
    (`modules/programs/claude-code-managed.nix`). It matches words in command
    text, so write prose (commit bodies, issue comments) to a file and pass it
    with `--body-file`.
  - Consult other models (Codex, Antigravity) only when the user asks, through
    the `second-opinion` skill. Never on your own initiative.
  ```

  The other two "Second opinions" bullets (untrusted advice, subscription
  login only) are already in `AGENTS.md` under **Delegating to other
  models**. They are dropped rather than written twice.

Codex and Antigravity read this section too. It costs four lines and says
nothing they must not do.

### 2. References are repointed

| File | Change |
| --- | --- |
| `catalog-info.yaml:108-109` | URL `…/blob/main/AGENTS.md`, title `Agent conventions (AGENTS.md)` |
| `docs/NIXOS-ANTI-PATTERNS.md:1124` | Link text and URL become `AGENTS.md` |
| `docs/guides/GITHUB-WORKFLOW.md:998` | Link text and URL become `AGENTS.md` |
| `docs/applications/sunshine.md:59` | `` `CLAUDE.md` `` becomes `` `AGENTS.md` `` |
| `modules/desktop/sunshine.nix:24` | `CLAUDE.md` becomes `AGENTS.md` (comment) |
| `modules/common/networking.nix:51` | `CLAUDE.md` becomes `AGENTS.md` (comment) |
| `.claude/agents/nix-anti-pattern-auditor.md:42-43` | "Repo-root `AGENTS.md` — repo conventions". The `.claude/CLAUDE.md` mention goes, because that file does not exist |
| `.claude/commands/nix-help.md:456, 540` | `.claude/CLAUDE.md` becomes `AGENTS.md` |
| `.claude/skills/tailscale.md:1004` | `CLAUDE.md` becomes `AGENTS.md` |

Left alone: every `intent/`, `spec/` and `plan/` file (they are records),
`home/development/agent-rules/global.md` and `codex-standards.md` (they
describe the global files and `~/.claude/CLAUDE.md`), `home/syncthing-stignore.nix`,
`modules/programs/claude-code-managed.nix`, `modules/services/nixarchy-runner.nix`
and `docs/tooling/claude-code-update-2.0.54.md`. The last one is a dated
changelog checklist.

### 3. `instructionFiles` is not pinned

The binary names the option and its modes. Setting it as a top-level
`.claude/settings.json` key had no effect in the scratch test. With
`{"instructionFiles":"claude-md"}`, and again with the legacy
`{"projectInstructions":"claude-md"}`, the codeword was still loaded. The
option belongs to a built-in feature (`agents-fallback`), and where that
feature reads its configuration is undocumented here. An unverifiable config
line is not added.

The guard is verification test 2 instead. It is run in this PR, and again by
anyone who suspects the default changed.

### 4. Stale docs are deleted

- `docs/tooling/CLAUDE-CODE-OPTIMIZATION.md` describes a `.claude/CLAUDE.md`
  guide that never existed in the tree. Deleting it also removes its nav entry
  from **both** `mkdocs.yml:207` and `mkdocs-full.yml:199`, and its mention at
  `docs/README.md:120`.
- `.claude/CLAUDE-CODE-2.1.2-UPDATES.md` is a one-off 2.1.2 upgrade note. It
  isn't referenced anywhere.

### 5. The nested `AGENTS.md` stays

`home/development/claude-code-skills/cosmic-ui-design-skill/AGENTS.md`
(154 lines) is vendored with the skill. In native mode it loads only when
Claude works inside that folder, which is exactly when it is relevant.

## Alternatives rejected

- **Keep the `CLAUDE.md` shim:** it works, but it is the one Claude-specific
  layer native support makes unnecessary. It also blocks the native path the
  issue is about.
- **Move the Claude-only rules to `.claude/rules/`:** that would need its own
  load verification, and it would split the repo rules across two places
  again, which is the drift #1832 removed.
- **`AGENTS.md` symlinked as `CLAUDE.md`:** it was rejected in #1832, and
  native loading makes it pointless.
- **Pin `projectInstructions`/`instructionFiles` anyway:** it was shown to have
  no effect as a settings key, so it would only look like protection.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| In the real repo, Claude loads less than it did through the `@` import | every session on p620, razer, p510 | Test 2 runs in the branch worktree with tools off before the PR is opened. If it fails, stop and restore `CLAUDE.md` |
| A future Claude Code changes the default to `claude-md` only, and the repo rules vanish silently | all hosts | Test 2 is the documented check. Nothing to pin (see §3) |
| The pre-push markdownlint lints whole touched files, so a one-line edit in a long doc surfaces its backlog | `docs/NIXOS-ANTI-PATTERNS.md`, `docs/guides/GITHUB-WORKFLOW.md`, `.claude/skills/tailscale.md`, `.claude/commands/nix-help.md` | Run markdownlint on each touched file before commit. Fix what it reports, in the same commit |
| mkdocs nav still points at the deleted doc | published site, Backstage TechDocs | The entry is removed from both nav files. Test 4 greps for it |
| Old worktrees or branches still carry `CLAUDE.md` | none | Harmless: those sessions keep loading through the `@` import as today |

Nothing is built or deployed. No host is touched.

## Verification

1. **Nothing left behind:**
   - `test ! -e CLAUDE.md`
   - `git grep -n 'CLAUDE\.md' -- ':!intent' ':!spec' ':!plan'` returns only
     the lines left alone in §2
   - `git grep -n '\.claude/CLAUDE\.md'` returns nothing outside the history
     files
2. **Claude reads `AGENTS.md` natively, with tools off.** From the repo root
   on the branch, with the prompt on stdin:

   ```sh
   echo "Which host must never be built or deployed without asking? Hostname only. Do not use tools." \
     | claude -p --disallowedTools Read Bash Grep Glob Agent
   ```

   The answer must be `p510`. A second question, "What must you pass prose
   through because of the PreToolUse hook?", must mention `--body-file`,
   which proves the moved section loads.
3. **Lint:** markdownlint passes on every touched `.md`. `yamllint`, or the
   pre-commit YAML check, passes on `catalog-info.yaml`.
4. **Docs nav:** neither `mkdocs.yml` nor `mkdocs-full.yml` names
   `CLAUDE-CODE-OPTIMIZATION`. If mkdocs is available, `mkdocs build --strict
   -f mkdocs-full.yml` reports no missing nav file.
5. **Nix comments only:** `just check-syntax` passes (two `.nix` files get
   comment edits only).
