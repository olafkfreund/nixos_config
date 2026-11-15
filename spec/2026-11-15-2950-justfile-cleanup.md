---
status: draft
issue: 2950
intent: intent/2026-11-15-2950-justfile-cleanup.md
---

# Spec: cut the Justfile down to the recipes the workflow uses

## Design

### Keep (44 public recipes + 2 private), grouped with `[group('...')]` (just 1.59)

| Group | Recipes |
|---|---|
| (none) | `default` |
| deploy | `deploy`, `p620`, `razer`, `p510`, `p510-clear-sessions`, `deploy-local-build`, `deploy-via-p620`, `build-on-p620`, `quick-deploy` |
| update | `update-commit-deploy`, `update-commit`, `update`, `preview-updates`, `system-diff`, `check-updates` |
| test | `test-host`, `test-all-parallel`, `quick-test`, `check-syntax`, `validate`, `validate-quick`, `dry-run`, `diff`, `test-guards`, `check-mcp` |
| maintenance | `status`, `cleanup`, `gc`, `boot-space`, `boot-space-clean`, `boot-space-all`, `ping-hosts` |
| secrets | `secrets`, `secrets-status`, `secrets-status-host`, `test-secrets`, `fix-agenix-remote` |
| lint | `format`, `lint-all`, `pre-commit-run` |
| docs | `docs-build`, `docs-serve`, `docs-check` |
| private | `_require-main`, `_sign-drv` |

Rule: shell-history use, plus every executable caller and dependency (Codex review). Kept recipes keep their name,
body and flags. The one exception: `deploy-smart`'s body moves into `quick-deploy`, which only called it. Its
`just {{HOST}}` dispatch stays, so `quick-deploy p620` still runs `just p620`.

### Drop (78)

Duplicates and unused variants:

- Deploy and test duplicates: `deploy-fast`, `deploy-cached`, `deploy-smart` (folded into `quick-deploy`),
  `emergency-deploy`, `pre-deploy`, `deploy-interactive`, `deploy-all`, `deploy-all-parallel`, `quick-all`, `test-all`, `test-build-all`,
  `test-build-all-parallel`, `build-all-parallel`, `test-build`, `test-build-verbose`.
- Garbage collection and store: `gc-aggressive`, `optimize`, `full-cleanup`, `clean-all`.
- Validation, pre-commit and formatting: `validate-quality`, `validate-full`, `pre-commit-install`,
  `pre-commit-staged`, `pre-commit-update`, `pre-commit-clean`, `pre-commit-hook`, `format-all`, `format-path`.
- Updates and status: `update-flake`, `update-input`, `update-workflow`, `new-packages`, `status-all` (it only calls
  `ping-hosts`).

Diagnostics (replaced by a "Plain nix commands" table in `docs/guides/` with the commands they wrapped):

- `perf-*`, `bench-host`, `analyze`, `efficiency-report`
- `trace-option`, `debug-module`, `diff-hosts`, `show-drv`, `show-build`, `show-diff`
- `repl`, `repl-nixpkgs`, `info`, `metadata`, `history`, `dev-shell`
- `check`, `check-module`, `check-module-docs`, `test-module`, `test-modules`, `test-home-modules`
- `test-package`, `test-packages`, `check-deprecated`, `security-scan`

Stale or unsafe: `test-nixpkgs-stable` (pins nixos-24.05), `test-kernel-version`, `test-rollback`, `ci`,
`ci-quick`, `ci-custom`, `ci-hosts`, `backup`, `restore` (restore overlays the shared checkout), `watch`,
`network-monitor`, `summary`, `help-extended`, `test-all-secrets`.

### Scripts

- Delete `scripts/ci-test.sh`, `scripts/find-new-packages.sh` and `scripts/generate-topology.sh` (only `deploy-all`
  called it). After the cut, nothing calls them except docs that get updated. (The `ci-test` key in
  `home/development/gitlab/default.nix` is an unrelated shell alias.)
- `deploy-all` goes (agy review): it deploys p510 by calling the p510 recipe without p510 on the command line, so
  the p510 deploy guard never sees it; it has no `_require-main` and deploys p620 twice. Multi-host deploys are one
  host recipe per host. The `deployment-coordinator` agent prompt (`.claude` and `.gemini`) says so.
- Keep every other script. `performance-test.sh`, `network-monitor.sh`, `test-modules.sh` and
  `validate-quality.sh` are called by `.claude`/`.gemini` slash commands and agents, and `check-boot-space.sh` by
  `scripts/update-commit-deploy.sh`.

### Callers

- `tools/default.nix` (`nixos-deploy`, `nixos-test` flake apps): drop the subcommands calling `deploy-all`,
  `deploy-all-parallel`, `emergency-deploy` and `test-all`; the rest point at kept recipes.
- `.pre-commit-config.yaml` calls `validate-quick` and `--list` (kept). Shell helpers `nhs`, `nhsb`, `fj`,
  `sysdiff`, `j`/`jl`/`jr` and the `jv`/`jth`/`jqt`/`jqd` abbreviations target kept recipes or scripts.
- Shell aliases `jv`, `jth`, `jqt`, `jqd`, and `nhs`: unchanged (all targets kept).
- `modules/programs/claude-code-managed.nix` permission list: drop `just test-all:*` only if nothing it matches
  survives. `test-all-parallel` survives, so it stays. No guard pattern changes.
- Live docs: every `just <recipe>` that targets this Justfile names a kept recipe with valid arguments, or becomes
  the plain command. Scope: `docs/`, `AGENTS.md`, root and module `README*`, `.claude/{agents,commands}`,
  `.gemini/{agents,commands}`, `home/development` (agent rules, output styles, mcp-config), `hosts`, `scripts`,
  `.github`, `tools`. This includes references that were already broken (`deployment-status`, `perf-baseline`,
  `test-coverage`, ...). Out of scope: `intent/`, `spec/`, `plan/` (history), and skills that describe other
  projects' Justfiles (e.g. `cosmic-ui-design-skill`).
- The `.claude`/`.gemini` agent examples citing `home/profiles/...` (removed in #2933) are fixed in the same pass.

### Safety, unchanged

- `_require-main` on every deploy recipe that has it today; `_sign-drv` dependencies; `ALLOW_BRANCH_DEPLOY`.
- p510 routes stay as they are. `just p510` switches in place; `update-commit-deploy p510` keeps `nh os boot` and its
  own branch check (`scripts/update-commit-deploy.sh:105`, `:482-488`). `deploy-local-build`/`deploy-via-p620` still
  accept p510. Owner approval and `P510_DEPLOY_APPROVED` are untouched, and nothing builds or deploys p510 in this
  work: nothing builds on or deploys to p510 (evaluating or building p510's config on p620, as `validate` and
  `quick-test` do, is allowed).
- Guard tests stay green: `test-guards`, `modules/programs/claude-coder-guard.test.sh`,
  `pkgs/claude-code-mods/fleet-guard/hooks/classify.test.ts`.
- Deploy recipe names still match the guards (`*deploy*`, `p620|p510|razer`) in
  `modules/programs/claude-code-managed.nix:538` and `claude-coder-guard.sh:86`.

## Alternatives rejected

- **Gentle cut** (exact duplicates only, ~70 left): the menu stays unreadable; owner chose the short menu.
- **`just debug <what>` dispatcher**: a new interface to maintain for commands that are one `nix` line each; owner
  chose plain commands in the docs.
- **Split into `just` modules (`mod deploy`)**: changes every invocation (`just deploy::p620`), breaking muscle
  memory, aliases and guard patterns.
- **Keep `emergency-deploy`**: its body is `razer`'s `nixos-rebuild` line behind a prompt. No recipe runs tests
  first, so it skips nothing.

## Risks

- A caller missed by the audit fails with "recipe not found". It is loud and immediate, not silent. Mitigated by
  the reference check in Verification.
- Docs that Home Manager ships (agent rules, skills, output styles) change the p620/razer/p510 toplevel by their
  text only. That is expected, and verified by the snapshot diff listing only those files.
- The bus hook does not match `just gc`/`just cleanup` (pre-existing gap, Codex review). Out of scope; filed as a
  follow-up issue.

## Verification

- `just --summary` equals the keep list. `just --list` shows the groups.
- For every kept recipe except `quick-deploy`, `just --show <r>` is unchanged against `main`, apart from the added
  `[group]` line.
- `just --dry-run` of `quick-deploy`, `p510`, `deploy-via-p620` and `update-commit-deploy` resolves without error. No
  real deploy.
- Reference check: in the live-doc scope, every `just <name>` resolves via `just --summary`. A grep loop, run in
  the PR.
- `nix flake check` / `just validate`, `just test-guards`, and `pre-commit run --all-files` on changed files.
- Snapshot: `SNAP_NO_BUILD=1 scripts/config-snapshot.sh` against main. Any changed host lists only the shipped doc
  files in `hmfiles`/`etc` content, with no package or unit changes.
- CI green, `@codex review` clean. Recipe and line counts before/after in the PR.
