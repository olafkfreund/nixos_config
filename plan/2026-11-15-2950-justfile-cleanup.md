---
status: draft
issue: 2950
spec: spec/2026-11-15-2950-justfile-cleanup.md
coders:
  1: codex  # 77 recipe deletions + group attributes, checked recipe by recipe against main's --show output
  2: codex  # caller and docs rewrite across ~100 live files, mechanical but needs judgement per reference
reviewers:
  - codex
  - agy
---

# Plan: cut the Justfile down to the recipes the workflow uses

Approved decisions (spec):

- Keep exactly these 45 public recipes plus `_require-main` and `_sign-drv`, each with `[group('<g>')]`:
  - (no group) `default`
  - deploy: `deploy p620 razer p510 p510-clear-sessions deploy-local-build deploy-via-p620 build-on-p620 quick-deploy
    deploy-all`
  - update: `update-commit-deploy update-commit update preview-updates system-diff check-updates`
  - test: `test-host test-all-parallel quick-test check-syntax validate validate-quick dry-run diff test-guards
    check-mcp`
  - maintenance: `status cleanup gc boot-space boot-space-clean boot-space-all ping-hosts`
  - secrets: `secrets secrets-status secrets-status-host test-secrets fix-agenix-remote`
  - lint: `format lint-all pre-commit-run`
  - docs: `docs-build docs-serve docs-check`
- Every other recipe is deleted (77; list in the spec).
- Kept recipes keep name, parameters, dependencies and body. Only `quick-deploy` changes: it takes over
  `deploy-smart`'s body, including the `just {{ HOST }}` dispatch.
- Delete `scripts/ci-test.sh` and `scripts/find-new-packages.sh`; keep all other scripts.
- p510 routes, `nh os boot` in `scripts/update-commit-deploy.sh`, `_require-main`, `_sign-drv`, guard patterns and
  `P510_DEPLOY_APPROVED` are untouched. Nothing builds or deploys p510.

## Steps

1. `Justfile`: delete the 77 recipes with their leading comment blocks; add `[group('<g>')]` above each kept recipe;
   move `deploy-smart`'s body into `quick-deploy`; drop section banners that now head nothing. Keep
   `set`/variable lines at the top.
   Check:
   - `just --summary | tr ' ' '\n' | sort` equals the keep list.
   - For each kept recipe except `quick-deploy`: `diff <(git show main:Justfile | just --justfile /dev/stdin --show r)
     <(just --show r | grep -v '^\[group')` is empty. (Write main's Justfile to a temp file for `--justfile`.)
   - `just --dry-run quick-deploy p620`, `just --dry-run p510` and `just --dry-run deploy-via-p620 razer` print the
     commands without error. `just test-guards` passes.
   Traps:
   - `just --dry-run` still runs dependencies' `@`-silenced shell and `#!` recipes. Do not dry-run recipes with
     shebang bodies or `_sign-drv` (it evaluates).
   - Never run a real deploy, gc or cleanup.
2. Callers and docs:
   - `scripts/ci-test.sh`, `scripts/find-new-packages.sh`: `git rm`; fix `scripts/README.md`.
   - `tools/default.nix`: remove the subcommands that call dropped recipes (`deploy-all-parallel`, `emergency-deploy`,
     `test-all`) and their usage lines.
   - Live docs: every `just <name>` in `docs/`, `AGENTS.md`, `README*`, `*/README.md`, `.claude/{agents,commands}`,
     `.gemini/{agents,commands}`, `home/development/{agent-rules,claude-code-output-styles.nix,claude-desktop}`,
     `hosts`, `scripts`, `.github`, `tools`, `UPDATE-TRACKING-SUMMARY.md` that names a recipe not in the keep list
     is rewritten to the kept equivalent (`emergency-deploy`/`deploy-fast`/`deploy-cached` → the host recipe or
     `deploy-local-build`, `test-all`/`quick-all`/`test-build-all*` → `test-all-parallel`, `check` → `validate`) or
     to the plain `nix` command (diagnostics). Applies to references that were already broken too (`deployment-status`,
     `perf-baseline`, `test-coverage`, `generate-docs`, `test-vm`, …): point at a real recipe/command or delete the
     sentence.
   - Same pass: `.claude/agents/{package-resolver,performance-analyzer}.md` and the `.gemini` copies replace
     `home/profiles/...` examples with `Users/olafkfreund/...` paths that exist.
   - Not in scope: `intent/`, `spec/`, `plan/`, and skills about other projects
     (`home/development/claude-code-skills/cosmic-ui-design-skill/`).
   Check: the reference loop below prints nothing; `markdownlint-cli2` on changed `.md` files passes.
   Traps:
   - The pre-push hook lints whole changed Markdown files, so fix pre-existing long lines in files you touch.
   - Write prose to files (bus hook matches command text).
3. Docs (Claude):
   - Add a "Plain nix commands" table in `docs/guides/` replacing the diagnostics recipes (`nix path-info -rsSh`,
     `nix repl .#`, `nix eval … --show-trace`, `nix flake show/metadata`, `nix store diff-closures`,
     `nixos-rebuild list-generations`), and link it from `mkdocs.yml` and `mkdocs-full.yml`.
   - Update the `AGENTS.md` Commands section.
   - File the follow-up issue: the bus hook does not match `just gc`/`just cleanup`.

Reference loop (step 2 check, run from the worktree):

```bash
keep=$(just --summary)
git grep -h -o -E '\bjust [a-z][a-z0-9-]*' -- docs AGENTS.md README.md '*/README.md' .claude/agents .claude/commands \
  .gemini/agents .gemini/commands home/development/agent-rules home/development/claude-code-output-styles.nix \
  home/development/claude-desktop hosts scripts .github tools UPDATE-TRACKING-SUMMARY.md \
  | awk '{print $2}' | sort -u | while read -r r; do
  case " $keep " in *" $r "*) ;; *) echo "unresolved: just $r" ;; esac
done
```

It may print English false positives (`just the`, `just a`). Each remaining name is checked by hand.

## Tests

- Step checks above.
- `just validate` and `just check-syntax`.
- `SNAP_NO_BUILD=1 scripts/config-snapshot.sh snap` against a fresh main snapshot. Changed hosts may differ only in
  shipped doc text (`syspkgs`/`units` lists identical).
- CI green, `@codex review`.
- The PR lists recipe counts (122 → 45) and line counts.

## Rollback

Revert the squash commit. The Justfile is not in any system closure, so no host needs a redeploy for a rollback,
except for shipped doc text.
