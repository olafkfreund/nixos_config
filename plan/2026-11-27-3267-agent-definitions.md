---
status: approved
issue: 3267
spec: spec/2026-11-27-3267-agent-definitions.md
coders:
  1: coder # render script, its fixtures and checks
  2: coder # module, import, activation, cleanup and doc edit
reviewers:
  - codex # plan review (one plan review)
  - agy # diff review by a provider other than the coder's
---

# Plan: One agent definition source for Claude, Codex and agy

Decisions (approved spec): `.claude/agents/*.md` is the only source. A
build-time render writes `gemini/<name>.md` (tier: haiku/sonnet → `flash`,
opus → `pro`, missing or other → `inherit`, plus a managed-marker comment)
and `codex/<name>.toml` (`name`, `description`, `developer_instructions`,
and `model` / `model_reasoning_effort` from
`modules/programs/agent-team.nix`: haiku → explorer, sonnet → worker,
opus → reviewer, missing or other → worker). Codex gets
`home.file.".codex/agents"`; agy gets real files copied by activation into
`~/.gemini/agents/` (Syncthing), with stale generated files and the known
stray `test-agent.md` removed. The repo's `.gemini/agents/` is deleted.

Revised after the Codex plan review: Unicode-safe TOML strings; a strict
frontmatter split; cleanup that touches only files this module generated;
fixtures for every mapping and edge case; wiring before the build check.

## Steps

1. Render script `home/development/agent-definitions.py` and its fixtures.
   - Usage: `agent-definitions.py <src-dir> <out-dir>`; roles come from
     the `roles` environment variable (JSON of `agent-team.nix`'s `roles`).
   - Frontmatter: line 1 must be exactly `---`; the frontmatter ends at the
     first later line that is exactly `---` (unindented); everything after
     that line is the body, kept byte for byte (blank lines included). Parse
     with `yaml.safe_load`; require string `name` and `description`; `name`
     must match `^[a-z0-9][a-z0-9-]*$` (it becomes a filename); fail on a
     duplicate name.
   - agy file `gemini/<name>.md`: line 1 `---`, line 2 exactly
     `# managed by nixos_config agent-definitions (#3267)`, then
     `yaml.safe_dump({"name": …, "description": …, "model": tier}, sort_keys=False, allow_unicode=True)`,
     then `---`, then the body.
   - Codex file `codex/<name>.toml`: five keys, each value
     `toml_str(v) = json.dumps(v, ensure_ascii=False).replace("\x7f", "\\u007f")`;
     then `tomllib.loads` the text and fail unless `developer_instructions`
     equals the body and the other four values equal their inputs.
   - Fail if no file was rendered; print the count.
   - Fixtures in `home/development/agent-definitions-fixtures/` with an
     expected-output check `home/development/agent-definitions.test.sh`
     that runs the script on the fixtures into a temp dir and compares:
     `opus.md` (→ `pro`, reviewer row), `missing-model.md` (→ `inherit`,
     worker row), `unknown-model.md` (`model: gpt` → `inherit`, worker row),
     `body-dashes.md` (a body containing a standalone `---` line, an emoji,
     a quote, a backslash and a U+007F byte — body kept whole in both
     outputs), `multiline.md` (a `|` block description plus extra `tools`
     and `context` keys — agy header holds exactly name, description,
     model). Negative fixtures, each run alone and expected to fail: no
     closing `---`, missing `description`, a name with `/`, and two files
     with one name.
   → verify: `bash home/development/agent-definitions.test.sh` prints
   `ALL PASSED`; running the script on `.claude/agents` renders 13 of each.

2. Module and wiring.
   - New `home/development/agent-definitions.nix`: `team = import ../../modules/programs/agent-team.nix;`,
     `src = ../../.claude/agents;`, and the render derivation:

     ```nix
     rendered = pkgs.runCommand "agent-definitions" {
       nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ];
       roles = builtins.toJSON team.roles;
     } ''
       python3 ${./agent-definitions.py} ${src} "$out"
       bash ${./agent-definitions.test.sh} ${./agent-definitions.py} ${./agent-definitions-fixtures}
     '';
     ```

     (the test script takes the script and fixtures paths as arguments, so
     the fixtures run in every build).
   - `home.file.".codex/agents".source = "${rendered}/codex";` (the directory
     does not exist on p620 or razer, checked 2026-11-27).
   - `home.activation.agentDefinitionsAgy` (`entryAfter [ "writeBoundary" ]`):
     `dir=$HOME/.gemini/agents`; create it; for each rendered agy file,
     install it (`$DRY_RUN_CMD install -m 0644`) unless `cmp -s` says it is
     already equal. Then remove only:
     - files in `$dir` whose line 2 is exactly the marker, whose name does
       not contain `sync-conflict`, and that are not in the rendered set;
     - `test-agent.md` only if its sha256 is
       `f2605ee60bb0af1645fe25ad5a4056032d5808ba337377bb2f4a1da02ea73179`
       (the stray copy on both hosts).
     Same-name hand copies are overwritten (the spec accepts this: they are
     older copies of the same agents). Never `exit`.
   - `home/development/default.nix`: import `./agent-definitions.nix` after
     `./antigravity-config.nix`, with a one-line comment naming #3267.
   - `git rm -r .gemini/agents`; `.gemini/GEMINI.md` line 74 says the
     agents are rendered from `.claude/agents/` into `~/.gemini/agents/`
     (#3267), and its list gains `nix-anti-pattern-auditor`.
   → verify (the lead commits first so the flake sees the new files):
   `just test-host p620`; in the built home-files, `.codex/agents` has 13
   TOML files and its sibling `gemini/` 13 Markdown files. Activation test
   against a temp `HOME` (run the activation script text with `HOME` set):
   stale marked file removed; a file with the marker only in its body kept;
   a `*.sync-conflict-*` copy kept; a `test-agent.md` with other content
   kept; the known stray removed; a second run changes nothing (no mtime
   change); a dry run (`DRY_RUN_CMD=echo`) writes nothing.
   Traps: `~/.gemini` must get real files, never store links; p510 also
   imports `home/development/default.nix` and would run the same
   activation on its next owner-approved deploy (identical output).

3. Lead: `just test-host razer`; agy diff review; PR; merge; bus
   announcement; switch p620, then razer via p620. Two hosts write the same
   synced files: both run the same generation right after each other, and
   identical bytes mean the second writes nothing. After the switch, on
   both hosts: `agy agents` lists 13 names including
   `nix-anti-pattern-auditor` and not `test-agent`;
   `ls ~/.codex/agents | wc -l` is 13; `codex -p review debug prompt-input x`
   exits 0. Whether Codex lists the custom agents is checked with its
   `/agents` view by the owner if wanted; it is not scriptable here.

## Tests

`agent-definitions.test.sh` (fixtures, in every build), the activation test
in step 2, both host builds, and the post-switch checks in step 3.

## Rollback

Revert the PR and switch again: the module and its activation disappear,
the copied agy files stay (current text of the same agents), and
`~/.codex/agents` goes with the home-files link.
