---
status: draft
issue: 2950
author: olafkfreund
---

# Intent: cut the Justfile down to the recipes the workflow uses

## Problem

`Justfile` has 122 recipes in 1161 lines. Most were added once and never used again, so `just --list` no longer
works as a menu and nobody can tell which recipe is the right one.

Evidence (shell history and repository callers, 2026-11-15):

- About a dozen recipes carry nearly all use: `deploy-local-build` (152 runs), `p510` (74), `razer` (66),
  `quick-deploy` (58), `update-commit-deploy` (47), `update-commit` (36), `deploy-via-p620` (26), `deploy` (21),
  `test-host` (17), `check-syntax` (16), `status` (7), `validate` (6). Roughly 90 recipes have no recorded run.
- Duplicates under different names. `deploy-cached`, `emergency-deploy` and `razer` run the same `nixos-rebuild`
  line, and `deploy-fast` adds only `--no-build-nix`. `quick-test` only calls `test-all-parallel`. There are 13 deploy
  variants, 7 "test all hosts" variants, 4 garbage-collection variants, 6 `perf-*`, 4 `ci-*`, 6 `pre-commit-*` and
  4 `validate-*`.
- Stale recipes:
  - `test-nixpkgs-stable` pins `nixos-24.05`.
  - `summary` calls p510 a server.
  - `backup`/`restore` copy the checkout over itself, which is unsafe in the shared `/etc/nixos` checkout.
  - `watch`, `deploy-interactive` and `efficiency-report` are unused helpers.
- Recipes are called from outside the Justfile. Removing or renaming one breaks the caller:
  - shell aliases `jv`, `jth`, `jqt`, `jqd` (`home/shell/bash.nix`, `zsh-enhancements.nix`)
  - `nhs`, which wraps `update-commit-deploy`
  - the `deployment-coordinator` agent, which uses `deploy-all`
  - the guard tests (`test-guards`)
  - GitHub workflow messages (`quick-deploy`, `test-all-parallel`)
  - about 340 Markdown files that mention recipes

## Proposed outcome

- `just --list` shows a short menu, roughly 30–40 recipes, grouped (deploy, test, update, maintenance, secrets,
  docs), one recipe per job.
- Every recipe that stays still works the same way. Deploy safety stays intact: `_require-main`, `_sign-drv`, the
  p510 session clearing, and the bus announcement the hook enforces.
- Nothing that calls a kept recipe breaks. Every caller of a dropped recipe is pointed at its replacement, and the
  docs only name recipes that exist.
- Measurable: recipe count and line count before/after in the PR, and a check that every `just <recipe>` named in
  the repo resolves.

## Affected users and systems

- The owner's command line: aliases and muscle memory for the frequently used recipes.
- `nhs` / `update-commit-deploy` and `scripts/update-commit-deploy.sh`.
- Agents that run recipes: `deployment-coordinator`, the agent rules in `home/development/agent-rules/global.md`, the
  claude-code output styles.
- Docs (`docs/`, `AGENTS.md`, READMEs, `.claude/commands`) and the GitHub workflow messages.
- No host configuration changes. The Justfile is not part of any system closure. Docs that Home Manager ships
  (skills, agent rules) do change the toplevel; that change is intended text.

## Constraints

- Keep every recipe in the usage list above. Keep their names, or keep an alias where a name changes.
- p510 rules unchanged: `just p510` stays the only p510 deploy path, and nothing builds or deploys p510 during this
  work.
- Keep the guards: `_require-main` on deploy recipes, `_sign-drv`, `test-guards`, `ALLOW_BRANCH_DEPLOY`.
- A deleted recipe whose job is still needed gets a replacement, either a kept recipe or a one-line note in the
  docs. No silent loss of a capability that is still used.
- Behaviour-preserving for the kept recipes: same commands, same flags.

## Open questions

1. Cut depth: a short menu (~30–40, everything without recorded use dropped) or a gentle cut (only exact
   duplicates and stale recipes, ~70 left)? Recommendation: the short menu.
2. Should one-off diagnostics (`perf-*`, `analyze`, `trace-option`, `debug-module`, `diff-hosts`, `show-*`, `repl`)
   move behind a single `just debug <what>` recipe, or be dropped with the plain `nix` commands documented once?
   Recommendation: drop them and document the commands.
3. Should the unused scripts the dropped recipes call (`scripts/performance-test.sh`, `ci-test.sh`,
   `test-modules.sh`, `network-monitor.sh`) be deleted in the same change, or left for a separate cleanup?
   Recommendation: delete each one that nothing else calls.
