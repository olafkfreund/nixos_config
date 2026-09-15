---
status: approved
issue: 1832
intent: intent/2026-09-15-1832-agents-md-parity.md
---

# Spec: every agent follows the same rules and process as Claude

The intent's open questions, as approved on 2026-09-15:

- **Agents in scope:** Codex and Antigravity.
- **Single source:** `AGENTS.md`, which `CLAUDE.md` imports.
- **Bus rule:** stays, without the wording about a hook that only Claude has.

## Design

There are two layers, and each one is written once.

### 1. The repo rules: `AGENTS.md` is the source, `CLAUDE.md` imports it

- **`AGENTS.md`** gets the full content of today's `CLAUDE.md`. That file is
  the current one: hosts, the non-negotiables, the bus rule, commands, git and
  the infrastructure notes. Two sections of the old, stale `AGENTS.md` still
  add something and are merged in: **Layout** (the directory map) and the
  **Build / test / deploy** command list. Everything else in the old file is
  replaced.
- **Tool-neutral wording**, only where the text is Claude-specific:
  - Rule 6 (announce before disrupting a host) keeps the procedure. Its hook
    sentence becomes: *"Claude Code enforces this with a PreToolUse hook
    (`modules/programs/claude-code-managed.nix`); other agents must do it
    themselves."*
  - `## Second opinions` describes a Claude-only skill, so it moves to
    `CLAUDE.md`.
- **`CLAUDE.md`** shrinks to Claude Code's import line plus what only Claude
  needs:

  ```markdown
  # CLAUDE.md

  @AGENTS.md

  ## Claude Code only

  - The bus rule above is enforced for you by a PreToolUse hook; prose that
    mentions deploy/switch/reboot words trips it — write it to a file and use
    `--body-file`.
  - ## Second opinions … (moved unchanged from today's CLAUDE.md)
  ```

  Claude Code expands `@path` imports in `CLAUDE.md`, so Claude sees exactly
  what Codex and Antigravity see, plus its own section.
- **`mkdocs.yml` / `mkdocs-full.yml`:** no change. Neither file lists
  `CLAUDE.md` or `AGENTS.md` in its nav (grep of both files, 2026-09-15: no match).

### 2. The global process: one generated file for Codex and Antigravity

Claude gets the intent → spec → plan gates from `/etc/claude-code/CLAUDE.md`
(`modules/programs/claude-code-managed-claude.md`), the templates from the
`artifact-workflow` skill, and PARR from the `UserPromptSubmit` hook
(`claude-code-managed.nix:25-71`). Codex and Antigravity get none of these.
They can't load skills or hooks, so they need the text itself.

A new Home Manager module, `home/development/agent-rules.nix`, builds **one**
file from the files that already exist. Nothing is copied by hand:

| Part | Source (read with `builtins.readFile`; none are secrets) |
| --- | --- |
| Global working rules | Today's `globalAgentsMd` text, moved out of `antigravity-config.nix:95-133` into `home/development/agent-rules/global.md`. Its short PARR paragraph is removed, because part 2 replaces it |
| PARR protocol | New `modules/programs/parr-protocol.md`, holding the text now inline in the hook's heredoc. The hook becomes `cat` of that file, wrapped in the same `<system-reminder>` tags, so Claude's reminder output is byte-identical |
| Workflow gates | `modules/programs/claude-code-managed-claude.md`, with one sentence swapped via `lib.replaceStrings`: "The procedure and templates are in the `artifact-workflow` skill. Load it before writing any of these files." becomes "The procedure and templates follow below." |
| Templates | `home/development/claude-code-skills/artifact-workflow/SKILL.md` with its YAML frontmatter removed (everything after the second `---` line) |

It is installed at two paths:

- `home.file.".codex/AGENTS.md"`, which Codex reads as its global
  instructions. The file doesn't exist today, and `~/.codex` is not synced.
- `home.file.".gemini/AGENTS.md"`, the path Antigravity already reads. It
  replaces `globalAgentsMd`. It isn't in the Syncthing allow-list
  (`home/syncthing-stignore.nix`), so a store link is fine there, as it is
  today.

`antigravity-config.nix` loses `globalAgentsMd` and its `home.file` line.
`home/development/default.nix` imports `./agent-rules.nix` next to
`./codex-cli.nix`.

Hosts: p620 and razer, through the home profile both already import. p510
gets the same files at its next deploy, as for every home file. It isn't
built or deployed for this.

## Alternatives rejected

- **Symlink `AGENTS.md → CLAUDE.md`:** the file would still be named and
  worded for Claude, and a symlinked instructions file is unreliable in some
  tools.
- **Keep two repo files in sync with a CI diff check:** the drift is caught,
  not prevented, and every edit has to be made twice.
- **Copy the workflow text into the global file by hand:** that is exactly
  the drift #1832 is about. Generating it from the three source files means a
  workflow change reaches every agent at the next rebuild.
- **Install the `artifact-workflow` skill into `~/.codex/skills` and
  `~/.gemini/skills`** (as `gog` is): it only works if the agent decides to
  load the skill. The gates have to be in the always-loaded instructions.
- **Also update the repo's `.gemini/GEMINI.md`:** that is Gemini CLI's file,
  and gemini-cli was removed (#560; its last mise copies were cleaned up
  today). Antigravity reads `AGENTS.md`. Left alone, and noted in the PR.
- **Add Copilot, OpenCode, Crush…:** out of scope for the intent. `AGENTS.md`
  at the repo root already reaches any agent that reads it.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| Claude Code doesn't expand `@AGENTS.md`, so Claude loses the repo rules | p620, razer | Verification test 2 checks a fresh `claude -p` session for a fact that only exists in `AGENTS.md`. If it fails, stop and keep `CLAUDE.md` whole |
| Moving the PARR text into a file changes what the hook emits | p620, razer, p510 (managed module) | Test 4 compares the hook's output before and after with `cmp` |
| `lib.replaceStrings` doesn't match (the sentence changes later), so the global file still says "load the skill" | all | A build-time `assert` that the generated text doesn't contain "Load it before writing" |
| Frontmatter stripping cuts real content | all | Test 5 checks the generated file contains "## Intent template" and doesn't contain `name: artifact-workflow` |
| Codex doesn't read `~/.codex/AGENTS.md` | p620, razer | Test 6 asks `codex exec` (read-only, subscription) for a phrase unique to the global file |
| The generated file is large and costs Codex/Antigravity context every session | all | About 250 lines. Acceptable, and the same material Claude already carries |

## Verification

1. **Build:** `just check-syntax`, `just test-host p620`, `just test-host
   razer`. Also evaluate `home-manager.users.olafkfreund.home.file` for p510
   (evaluation only, no build).
2. **Claude still sees the repo rules:** from the repo, `claude -p "Which
   host must never be built or deployed without asking? Answer with the
   hostname only."` → `p510`, with `CLAUDE.md` holding no host table itself.
   `claude -p "What does the bus rule tell you to run before a deploy?"`
   mentions `read_new`.
3. **One source:** `grep -c '^| p620' CLAUDE.md` → `0`, and the same grep on
   `AGENTS.md` → `1`.
4. **PARR hook unchanged:** run the hook script from before and after the
   change, then `cmp` the two outputs → identical.
5. **Generated global file** (`~/.codex/AGENTS.md` and `~/.gemini/AGENTS.md`
   after deploy):
   - it contains "## Artifact workflow", "## Intent template",
     "MANDATORY: Follow PARR" and "The procedure and templates follow below"
   - it contains neither "Load it before writing" nor `name: artifact-workflow`
   - both paths resolve to the same store file
6. **Agents read it:**
   - Codex, with the skill's subscription command (read-only): *"Before
     implementing a multi-file task, which three files must exist and be
     approved? Answer with the three folder names."* → intent, spec, plan.
   - The same question to `agy --mode plan … -p` → intent, spec, plan.
7. **Nothing else changed:** the second-opinion skill still loads, and the
   Antigravity MCP sync (`antigravityMcpSync` activation) runs without errors.
