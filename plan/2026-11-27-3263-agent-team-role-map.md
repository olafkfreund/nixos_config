---
status: draft
issue: 3263
spec: spec/2026-11-27-3263-agent-team-role-map.md
coders:
  1: coder # new data file and three mechanical Claude-side edits
  2: coder # Codex profile files, alias and one activation rewrite
  3: coder # agy worker values and herdr-team review argv + test line
reviewers:
  - codex # plan review (owner policy 2026-11-27: one plan review)
  - agy # diff review by a provider other than the coder's
---

# Plan: One role map for Claude, Codex and agy models

Decisions (from the approved spec): one plain data file
`modules/programs/agent-team.nix` (roles manager/reviewer/worker/explorer ×
claude/codex/agy, each `{ model; effort; }`, plus `limits = { subagents = 4;
depth = 1; }`); values exactly as in the spec table. Consumers read it by
path import. Claude keeps today's values; Codex implement moves to
`gpt-6.2-sol`; a Codex manager profile and forced `review_model` are added;
herdr-team's Codex reviewer gets the reviewer model.

## Steps

1. Claude side.
   - Create `modules/programs/agent-team.nix` with the spec's attrset and a
     one-line header comment naming #3263.
   - `modules/programs/claude-code-managed.nix`: add
     `team = import ./agent-team.nix;` to the top `let`. In `mergedSettings.env`
     (around lines 843-849) set `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS =
     toString team.limits.subagents;`, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH =
     toString team.limits.depth;`, `CLAUDE_CODE_SUBAGENT_MODEL =
     team.roles.worker.claude.model;` (keep the existing comments).
     `coderAgent` (around line 434): extend the `replaceStrings` with
     `"@model@" "@effort@"` → `team.roles.worker.claude.model` /
     `.effort`.
   - `modules/programs/claude-code-coder-agent.md:8`: `model: @model@`, then
     `effort: @effort@`, then

     ```yaml
     experimental:
       cacheTtl: 1h
     ```

   - `home/development/claude-code-agents.nix`: add
     `team = import ../../modules/programs/agent-team.nix;` to the `let`;
     Explore's frontmatter uses `model: ${team.roles.explorer.claude.model}`,
     adds `effort: ${team.roles.explorer.claude.effort}` and
     `omitClaudeMd: true`.
   → verify: `nix eval --raw .#nixosConfigurations.p620.config.environment.etc."claude-code/managed-settings.json".text | jq .env`
   shows sonnet / 4 / 1 (find the right attr with `grep -n managed-settings.json modules/programs/claude-code-managed.nix` if this name is wrong);
   the built coder agent file (`grep -n coder.md` in the same module for its
   install path) shows `model: sonnet`, `effort: medium`, `cacheTtl: 1h`.
   Traps: Nix `''` strings: `${...}` interpolates, which is what we want in
   the Explore text; keep `@guard@` replacement working.

2. Codex side, `home/development/codex-cli.nix`.
   - Add `team = import ../../modules/programs/agent-team.nix;` and a small
     helper in the `let` that renders a profile:
     `profile = r: extra: ''model = "${r.model}"\nmodel_reasoning_effort = "${r.effort}"\n'' + extra + agentsTable;`
     with `agentsTable` = `\n[agents]\nmax_threads = <subagents>\nmax_depth = <depth>\n`
     (TOML: root keys must come before the table).
   - `implement.config.toml` (lines 75-83): `worker.codex` root keys, keep
     `sandbox_mode`/`approval_policy` lines and the header comment, then the
     `[agents]` table.
   - New `home.file.".codex/manager.config.toml".text`: comment naming
     #3263, `manager.codex` root keys, `review_model = "<reviewer.codex.model>"`,
     then `[agents]`.
   - `programs.codex-cli.shellAliases`: add `codex-manager = "codex -p manager";`.
   - `codexReviewModel` activation (lines 111-119): replace with an awk pass
     modelled on `codexUnrestricted` that rewrites a root-level
     `review_model = …` line to the reviewer model, or prepends it when
     absent; install only when the file changed.
   → verify: `just test-host p620` builds; after build, run
   `codex -p implement debug prompt-input x` style validation by copying the
   two generated profile files to `~/.codex/zz3263a.config.toml` and
   `zz3263b.config.toml`, running `codex -p zz3263a debug prompt-input x` and
   `codex -p zz3263b …` (exit 0 each), then deleting both.
   Traps: never write `config.toml` wholesale; `$DRY_RUN_CMD` before
   `install`; activation entries must not `exit`.

3. agy and herdr.
   - `home/development/antigravity-config.nix`: `team = import ../../modules/programs/agent-team.nix;`
     in the `let`; line 196 becomes
     `model="--model ${team.roles.worker.agy.model}-${team.roles.worker.agy.effort}"`;
     line 212's ACP flags become
     `--model ${team.roles.worker.agy.model} --effort ${team.roles.worker.agy.effort}`
     inside the existing `''${model:+…}`.
   - `home/development/agent-run.nix:21` (the herdr-team `text` prefix):
     add `review_model=<reviewer.codex.model>\nreview_effort=<reviewer.codex.effort>\n`
     (import the map at the top of that file).
   - `home/development/herdr-team.sh` review branches at ~502-504 and
     ~756-758: append `-c "model=\"${review_model:?}\"" -c "model_reasoning_effort=\"${review_effort:?}\""`
     after `-c forced_login_method=chatgpt`.
   - `home/development/herdr-team-test.sh:360`: expected launch line gains
     `-c model="gpt-6.2-astra" -c model_reasoning_effort="medium"` at the
     same position (escaped as the line already escapes quotes).
   → verify: `nix build .#nixosConfigurations.p620.config.system.build.toplevel`
   (herdr-team's checkPhase runs shellcheck and herdr-team-test.sh); the built
   `agy-implement` contains `gemini-4-hydrogen-medium` and
   `--model gemini-4-hydrogen --effort medium`.
   Traps: herdr-team.sh runs under `set -u`-style checks via `:?`; the test
   compares the full line, so order matters.

4. Builds, review, deploy (lead only): `just check-syntax`,
   `just test-host p620`, `just test-host razer`; agy diff review; PR; merge;
   bus announce; deploy p620 then razer via p620. Post-deploy checks from the
   spec's Verification.

## Tests

- `just test-host p620` and `just test-host razer` succeed (includes
  herdr-team's build-time tests).
- Profile validation via `codex -p … debug prompt-input x` exits 0.
- Post-deploy: `grep '^review_model' ~/.codex/config.toml` shows
  `gpt-6.2-astra`; `grep omitClaudeMd ~/.claude/agents/Explore.md`.

## Rollback

Revert the PR and redeploy; `review_model` in `config.toml` keeps the
forced value until edited (harmless).
