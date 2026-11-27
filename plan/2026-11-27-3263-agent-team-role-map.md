---
status: approved
issue: 3263
spec: spec/2026-11-27-3263-agent-team-role-map.md
coders:
  1: coder # new data file and three mechanical Claude-side edits
  2: coder # Codex profile files, alias and one activation rewrite
  3: coder # agy worker values and herdr-team review argv + tests
reviewers:
  - codex # plan review (owner policy 2026-11-27: one plan review)
  - agy # diff review by a provider other than the coder's
---

# Plan: One role map for Claude, Codex and agy models

Decisions (from the approved spec): one plain data file
`modules/programs/agent-team.nix`, imported by path by every consumer:

```nix
# One role map for Claude Code, Codex and agy (#3263).
{
  roles = {
    manager = {
      claude = { model = "opus"; effort = "high"; };
      codex = { model = "gpt-6.2-astra"; effort = "high"; };
      agy = { model = "gemini-4-neon"; effort = "high"; };
    };
    reviewer = {
      claude = { model = "opus"; effort = "medium"; };
      codex = { model = "gpt-6.2-astra"; effort = "medium"; };
      agy = { model = "gemini-4-neon"; effort = "medium"; };
    };
    worker = {
      claude = { model = "sonnet"; effort = "medium"; };
      codex = { model = "gpt-6.2-sol"; effort = "medium"; };
      agy = { model = "gemini-4-hydrogen"; effort = "medium"; };
    };
    explorer = {
      claude = { model = "haiku"; effort = "low"; };
      codex = { model = "gpt-6-luna"; effort = "low"; };
      agy = { model = "gemini-4-hydrogen"; effort = "low"; };
    };
  };
  limits = { subagents = 4; depth = 1; };
}
```

Claude keeps today's values; Codex implement moves to `gpt-6.2-sol`; a Codex
manager profile and a forced `review_model` are added; herdr-team's Codex
reviewer gets the reviewer model. The lead commits each step before its
verify, so the flake sees new files.

## Steps

1. Claude side.
   - Create `modules/programs/agent-team.nix` exactly as above.
   - `modules/programs/claude-code-managed.nix`: add
     `team = import ./agent-team.nix;` to the top `let`. In
     `mergedSettings.env` (lines ~843-849):
     `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = toString team.limits.subagents;`,
     `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = toString team.limits.depth;`,
     `CLAUDE_CODE_SUBAGENT_MODEL = team.roles.worker.claude.model;` (keep the
     existing comments). `coderAgent` (line ~434): extend the
     `replaceStrings` lists with `"@model@" "@effort@"` →
     `team.roles.worker.claude.model` and `team.roles.worker.claude.effort`.
   - `modules/programs/claude-code-coder-agent.md:8`: replace `model: sonnet`
     with three entries: `model: @model@`, `effort: @effort@`, and

     ```yaml
     experimental:
       cacheTtl: 1h
     ```

   - `home/development/claude-code-agents.nix`: add
     `team = import ../../modules/programs/agent-team.nix;` to the `let`;
     Explore's frontmatter becomes `model: ${team.roles.explorer.claude.model}`,
     `effort: ${team.roles.explorer.claude.effort}`, `omitClaudeMd: true`.
   → verify:
   `jq .env "$(nix build --no-link --print-out-paths '.#nixosConfigurations.p620.config.environment.etc."claude-code/managed-settings.json".source')"`
   shows `"sonnet"`, `"4"`, `"1"`;
   `head -16 "$(nix build --no-link --print-out-paths '.#nixosConfigurations.p620.config.environment.etc."claude-code/.claude/agents/coder.md".source')"`
   shows `model: sonnet`, `effort: medium`, `cacheTtl: 1h` and a store path
   for the guard.
   Traps: in the Explore `''` text, `${...}` is Nix interpolation (wanted);
   keep `@guard@` replacement working.

2. Codex side, `home/development/codex-cli.nix`.
   - `let`: `team = import ../../modules/programs/agent-team.nix;` and an
     `agentsTable` indented string with physical newlines (never `\n`):

     ```nix
     agentsTable = ''

       [agents]
       max_threads = ${toString team.limits.subagents}
       max_depth = ${toString team.limits.depth}
     '';
     ```

   - `implement.config.toml` (lines 75-83): keep the header comment,
     `model = "${team.roles.worker.codex.model}"`,
     `model_reasoning_effort = "${team.roles.worker.codex.effort}"`,
     `sandbox_mode`, `approval_policy`, then `+ agentsTable`. Root keys
     always above `[agents]`.
   - New `home.file.".codex/manager.config.toml".text`: comment naming #3263,
     `model` / `model_reasoning_effort` from `manager.codex`,
     `review_model = "${team.roles.reviewer.codex.model}"`, then
     `+ agentsTable`.
   - `programs.codex-cli.shellAliases`: add `codex-manager = "codex -p manager";`.
   - `codexReviewModel` activation (lines 111-119): replace with an awk pass
     in which any line matching `^[[:space:]]*\[` starts a table; before the
     first table a line matching `^[[:space:]]*"?review_model"?[[:space:]]*=`
     becomes `review_model = "<reviewer.codex.model>"` and sets a flag; at
     END with no flag, print that line first, then the file. Install the
     result (`$DRY_RUN_CMD install -m 0600`) only if it differs and parses:
     `${pkgs.python3}/bin/python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$tmp"`.
     If it does not parse, leave `config.toml` alone and print one warning
     line. Never `exit` in the activation.
   → verify: `just test-host p620` builds. Copy the two generated profiles
   from the built home-files to `~/.codex/zz3263a.config.toml` and
   `~/.codex/zz3263b.config.toml`; `codex -p zz3263a debug prompt-input x` and
   `codex -p zz3263b debug prompt-input x` exit 0 (no model call); delete
   both. Run the awk + parse step on four temp files: no `review_model`;
   root `review_model = "old"`; root `"review_model" = "old"`; and a
   `review_model` only under an indented `[profiles.x]` table. Each
   result parses, has exactly one root `review_model` with the new value,
   and the table's line is unchanged.
   Traps: never write `config.toml` wholesale.

3. agy and herdr.
   - `home/development/antigravity-config.nix`:
     `team = import ../../modules/programs/agent-team.nix;` in the `let`;
     line 196 becomes
     `model="--model ${team.roles.worker.agy.model}-${team.roles.worker.agy.effort}"`;
     line 212's flags inside the existing `''${model:+…}` become
     `--model ${team.roles.worker.agy.model} --effort ${team.roles.worker.agy.effort}`.
   - `home/development/agent-run.nix`: import the map at the top; the
     herdr-team `text` prefix (line 21) gains
     `review_model=${team.roles.reviewer.codex.model}\nreview_effort=${team.roles.reviewer.codex.effort}\n`
     (same `\n`-joined style as the existing prefix).
   - `home/development/herdr-team.sh` review branches (~502-504 and
     ~756-758): right after `-c forced_login_method=chatgpt` add
     `-c "model=\"${review_model:?}\"" -c "model_reasoning_effort=\"${review_effort:?}\""`.
   - `home/development/herdr-team-test.sh:360`: in the expected TUI launch
     line, right after `-c forced_login_method=chatgpt`, insert
     `-c model=\"gpt-6.2-astra\" -c model_reasoning_effort=\"medium\"` (the
     string is double-quoted, so the inner quotes are escaped).
   - `home/development/herdr-team-test.sh:1662` (hc backend): add, beside the
     `--no-daemon` check,
     `grep -qF -- '-c model="gpt-6.2-astra" -c model_reasoning_effort="medium"' "$TEST_STATE/launched" || die 'hc review model'`.
   → verify: `nix build --no-link .#nixosConfigurations.p620.config.system.build.toplevel`
   (herdr-team's checkPhase runs shellcheck and herdr-team-test.sh); the built
   `agy-implement` still contains `gemini-4-hydrogen-medium` and
   `--model gemini-4-hydrogen --effort medium`.
   Traps: the test compares the full line, so flag order matters.

4. Lead only: `just check-syntax`, `just test-host p620`, `just test-host razer`;
   agy diff review; PR; merge; bus announcement; switch p620, then razer via
   p620; the post-switch checks below.

## Tests

- `just test-host p620` and `just test-host razer` succeed (they include
  herdr-team's build-time tests).
- Step 2's profile and awk checks.
- After the switch, on p620 and on razer:
  `codex -p manager debug prompt-input x` and
  `codex -p implement debug prompt-input x` exit 0;
  `grep '^review_model' ~/.codex/config.toml` shows `gpt-6.2-astra`;
  `grep omitClaudeMd ~/.claude/agents/Explore.md` matches;
  `grep -o 'gemini-4-hydrogen[-a-z]*' "$(readlink -f "$(command -v agy-implement)")"`
  shows the worker model.

## Rollback

Revert the PR and switch again; the forced `review_model` stays in
`config.toml` until edited (harmless).
