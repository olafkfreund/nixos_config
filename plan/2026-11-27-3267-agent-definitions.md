---
status: draft
issue: 3267
spec: spec/2026-11-27-3267-agent-definitions.md
coders:
  1: coder # one new module with a small render script and its checks
  2: coder # import line, delete a directory, one doc line
reviewers:
  - codex # plan review (one plan review)
  - agy # diff review by a provider other than the coder's
---

# Plan: One agent definition source for Claude, Codex and agy

Decisions (approved spec): `.claude/agents/*.md` is the only source. A
build-time render writes `gemini/<name>.md` (tier: haiku/sonnet → `flash`,
opus → `pro`, else `inherit`, plus a managed-marker comment) and
`codex/<name>.toml` (`name`, `description`, `developer_instructions`, and
`model` / `model_reasoning_effort` from `modules/programs/agent-team.nix`:
haiku → explorer, sonnet → worker, opus → reviewer, else worker). Codex gets
`home.file.".codex/agents"`; agy gets real files copied by activation into
`~/.gemini/agents/` (Syncthing), with marked files no longer generated and
the stray `test-agent.md` removed. The repo's `.gemini/agents/` is deleted.

## Steps

1. New `home/development/agent-definitions.nix` (HM module):
   - `let team = import ../../modules/programs/agent-team.nix;` and
     `src = ../../.claude/agents;`.
   - The render derivation:

     ```nix
     rendered = pkgs.runCommand "agent-definitions" {
       nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ];
       roles = builtins.toJSON team.roles;
     } ''python3 ${./agent-definitions.py} ${src} "$out"'';
     ```

     with the script in a new `home/development/agent-definitions.py`
     reading the roles from the `roles` environment variable (JSON).
   - The script, for each `*.md` in sorted order: require a first line
     `---` and a closing `---`; parse the frontmatter with `yaml.safe_load`;
     require string `name` and `description`; fail on a duplicate `name`;
     `alias = model` (default `sonnet`); write
     - `$out/gemini/<name>.md`: `---`, the line
       `# managed by nixos_config agent-definitions (#3267)`, `name: …`,
       `description: …` (both via `yaml.safe_dump` of a dict so quoting is
       right), `model: <tier>`, `---`, then the body unchanged;
     - `$out/codex/<name>.toml`: `name = …`, `description = …`,
       `developer_instructions = …`, `model = …`,
       `model_reasoning_effort = …`, each value `json.dumps(str)`; then
       `tomllib.loads` the text and fail if it does not parse or round-trip
       the body.
     Print the count; fail if it is zero.
   - `home.file.".codex/agents".source = "${rendered}/codex";`
   - `home.activation.agentDefinitionsAgy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''…''`:
     `dir="$HOME/.gemini/agents"`; `mkdir -p "$dir"` (`$DRY_RUN_CMD`); for each
     file in `${rendered}/gemini/`, `cmp -s` against the target and
     `$DRY_RUN_CMD install -m 0644` when different; then for each `*.md`
     in `$dir` whose content contains the marker line and whose name is
     not in the rendered set, `$DRY_RUN_CMD rm -f`; finally
     `$DRY_RUN_CMD rm -f "$dir/test-agent.md"`. Never `exit`.
   → verify: `nix build --no-link --print-out-paths '.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home-files'`
   builds; in it `.codex/agents/` has 13 `.toml` files; build the
   `rendered` derivation (e.g. via `nix eval` of the home-file `source`) and
   check `gemini/` has 13 files with `model: flash|pro`; run the activation
   snippet against a temp `HOME` holding a marked stale file, an unmarked
   hand file and `test-agent.md`: the marked stale and `test-agent.md` go,
   the hand file stays, the 13 are present.
   Traps: `~/.gemini` must get real files, not store links; the script
   gets the source as a store path, so `src` must be a path literal.

2. Wiring and cleanup.
   - `home/development/default.nix`: import `./agent-definitions.nix` next to
     `./antigravity-config.nix`, with a one-line comment naming #3267.
   - `git rm -r .gemini/agents`.
   - `.gemini/GEMINI.md` line 74: `**System Agents** (rendered from
     \`.claude/agents/\` into \`~/.gemini/agents/\`, #3267):`.
   → verify:`just test-host p620` and `just test-host razer`.

3. Lead: agy diff review; PR; merge; bus announcement; switch p620, then
   razer via p620; then `agy agents` lists 13 (including
   `nix-anti-pattern-auditor`, not `test-agent`), `ls ~/.codex/agents | wc -l`
   is 13, and `codex -p review debug prompt-input x` exits 0, on both hosts.

## Tests

The render's own checks (in the build), the activation check in step 1,
both host builds, and the post-switch checks in step 3.

## Rollback

Revert the PR and switch again; the copied agy files stay (current text of
the same agents), and `~/.codex/agents` goes with the home-files link.
