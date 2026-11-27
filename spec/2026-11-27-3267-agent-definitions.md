---
status: approved
issue: 3267
intent: intent/2026-11-27-3267-agent-definitions.md
---

# Spec: One agent definition source for Claude, Codex and agy

## Design

New Home Manager module `home/development/agent-definitions.nix`, imported
explicitly from `home/development/default.nix`.

- A build-time derivation (`pkgs.runCommand` with `python3` plus PyYAML)
  reads every `.claude/agents/*.md` (the directory passed as a store path),
  splits YAML frontmatter from the body, and writes:
  - `gemini/<name>.md`: frontmatter `name`, `description`, `model` (tier:
    haiku and sonnet → `flash`, opus → `pro`, anything else → `inherit`),
    a YAML comment line `# managed by nixos_config agent-definitions (#3267)`,
    then the body unchanged.
  - `codex/<name>.toml`: `name`, `description`, `developer_instructions`
    (the body), `model` and `model_reasoning_effort` from
    `modules/programs/agent-team.nix` (haiku → explorer, sonnet → worker,
    opus → reviewer, other → worker). Strings are written as TOML basic
    strings via `json.dumps` (JSON escapes are valid TOML escapes).
  - The build fails if a file lacks `name` or `description`, if two files
    share a `name`, or if a generated TOML file does not parse with
    `tomllib`.
- `home.file.".codex/agents".source` = the `codex/` output (Codex's
  directory is not synced, so a store link is fine).
- An activation step copies each `gemini/` file into `~/.gemini/agents/`
  (`install -m 0644`, `$DRY_RUN_CMD`), skipping files already equal; then
  deletes files in that directory that carry the managed marker but are no
  longer generated, plus the known stray `test-agent.md`. Files without the
  marker are left alone.
- The repo's `.gemini/agents/` is deleted, and `.gemini/GEMINI.md` points at
  `.claude/agents/` as the source.

## Alternatives rejected

- Regenerating `.gemini/agents/` in the repo with a drift check: agy does
  not read a workspace's `.gemini/agents/` (it reads `.agents/agents/`), so
  that copy serves nothing.
- Writing the agy files with `home.file`: store symlinks break under
  Syncthing.

## Risks

- agy's tier mapping (`flash`, `pro`) is documented but its concrete models
  are not; the launcher still chooses the model for `agy-implement`.
- Overwriting the 12 same-named hand copies in `~/.gemini/agents/`: they
  are older copies of the same agents, now replaced by the current text.

## Verification

- `just test-host p620`, `just test-host razer` (the derivation's checks run
  in the build).
- After the switch: `agy agents` lists the 13 agents, including
  `nix-anti-pattern-auditor` and not `test-agent`; `ls ~/.codex/agents`
  shows 13 TOML files; `codex -p review debug prompt-input x` still exits 0.
