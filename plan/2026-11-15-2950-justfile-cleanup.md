---
status: approved
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

- Keep exactly these 44 public recipes plus `_require-main` and `_sign-drv`, each with `[group('<g>')]`:
  - (no group) `default`
  - deploy: `deploy p620 razer p510 p510-clear-sessions deploy-local-build deploy-via-p620 build-on-p620 quick-deploy`
  - update: `update-commit-deploy update-commit update preview-updates system-diff check-updates`
  - test: `test-host test-all-parallel quick-test check-syntax validate validate-quick dry-run diff test-guards
    check-mcp`
  - maintenance: `status cleanup gc boot-space boot-space-clean boot-space-all ping-hosts`
  - secrets: `secrets secrets-status secrets-status-host test-secrets fix-agenix-remote`
  - lint: `format lint-all pre-commit-run`
  - docs: `docs-build docs-serve docs-check`
- Every other recipe is deleted (78; list in the spec), including `deploy-all` (implicit p510 deploy that bypasses
  the p510 guard).
- Kept recipes keep name, parameters, dependencies and body, with two exceptions:
  - `quick-deploy HOST: _require-main` takes over `deploy-smart`'s body, including the `{{ HOST }}` dispatch.
  - `test-all-parallel` exits non-zero when any host build fails (today it always succeeds: `|| echo` plus a bare
    `wait`). Keep its output lines; collect each background build's status and `exit 1` if any failed.
- Delete `scripts/ci-test.sh`, `scripts/find-new-packages.sh`, `scripts/generate-topology.sh`; keep all other
  scripts.
- p510 routes, `nh os boot` in `scripts/update-commit-deploy.sh`, `_require-main`, `_sign-drv`, guard patterns and
  `P510_DEPLOY_APPROVED` are untouched. Nothing builds or deploys p510.

## Steps

1. `Justfile`: delete the 78 recipes with their leading comment blocks; add `[group('<g>')]` above each kept recipe;
   move `deploy-smart`'s body into `quick-deploy`; drop section banners that now head nothing. Keep
   `set`/variable lines at the top.
   Check:
   - `just --summary | tr ' ' '\n' | sort` equals the keep list.
   - For each kept recipe except `quick-deploy` and `test-all-parallel`: `git show main:Justfile > /tmp/jf-main` and
     `diff <(just --justfile /tmp/jf-main --working-directory . --show r) <(just --show r | grep -v '^\[group')` is
     empty.
   - Call graph: every `just <name>` inside a kept recipe body names a kept recipe:
     `grep -o -E 'just [a-z][a-z0-9-]*' Justfile` against `just --summary`. `--dry-run` does not prove this, because
     nested `just` calls are only printed.
   - `just --dry-run quick-deploy p620`, `p510`, `deploy-via-p620 razer` and `update-commit-deploy p620` print their
     commands without error (just 1.59 prints, never runs, dependencies and shebang bodies under `--dry-run`).
   - `test-all-parallel` failure path: run its body with each `nix build` swapped for `false`, in a temp copy, and see
     exit 1. Do not run real builds of all hosts here.
   - `just test-guards` passes.
   Traps: never run a real deploy, gc or cleanup.
2. Callers and docs:
   - `scripts/ci-test.sh`, `scripts/find-new-packages.sh`, `scripts/generate-topology.sh`: `git rm`; fix
     `scripts/README.md`.
   - `tools/default.nix`: remove the subcommands that call dropped recipes (`deploy-all`, `deploy-all-parallel`,
     `emergency-deploy`, `test-all`) and their usage lines.
   - `.claude/agents/deployment-coordinator.md` and the `.gemini` copy: multi-host deploys run one host recipe per
     host (p620 local, razer via p620, p510 only with the owner's OK); no `deploy-all`.
   - Live docs: every `just <name>` in `docs/`, `AGENTS.md`, `README*`, `*/README.md`, `.claude/{agents,commands,skills}`,
     `.gemini/{agents,commands,skills}`, `home/development/{agent-rules,claude-code-output-styles.nix,claude-desktop}`,
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
   - Arguments: a reference must match the recipe's parameters (`just --show <r>`), e.g. `deploy` takes none, so
     `just deploy HOST` becomes the host recipe.
   Check: the reference loop below exits 0; `markdownlint-cli2` on changed `.md` files passes;
   `bash modules/programs/claude-coder-guard.test.sh` and the `test-guards` recipe pass.
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
bad=$(git grep -h -o -E '`just [a-z][a-z0-9-]*|^\s*just [a-z][a-z0-9-]*|run: just [a-z][a-z0-9-]*' -- docs AGENTS.md \
  README.md '*/README.md' .claude/agents .claude/commands .claude/skills .gemini/agents .gemini/commands .gemini/skills \
  home/development/agent-rules home/development/claude-code-output-styles.nix home/development/claude-desktop \
  hosts scripts .github tools UPDATE-TRACKING-SUMMARY.md \
  | grep -o -E 'just [a-z][a-z0-9-]*' | awk '{print $2}' | sort -u | while read -r r; do
    case " $keep " in *" $r "*) ;; *) echo "$r" ;; esac
  done)
[ -z "$bad" ] || { echo "unresolved: $bad"; exit 1; }
```

It matches commands (in backticks, at line start in code blocks, after `run:`), not prose, so English words like
"just the" do not count. Arguments are checked by hand per the rule above.

## Tests

- Step checks above.
- `just validate` and `just check-syntax`.
- Snapshot proof that only shipped doc text changed:
  - In a worktree at `origin/main`: `SNAP_NO_BUILD=1 scripts/config-snapshot.sh snap /tmp/s50-base`.
  - In this worktree, with every changed file under `home/` restored from main
    (`git diff --name-only origin/main -- home | xargs git checkout origin/main --`):
    `SNAP_NO_BUILD=1 scripts/config-snapshot.sh snap /tmp/s50-nohome` and
    `scripts/config-snapshot.sh diff /tmp/s50-base /tmp/s50-nohome` prints IDENTICAL for p620, razer and p510.
    Then restore the branch's files with `git checkout HEAD -- home`.
  - This proves the only system difference is the text of the shipped `home/` docs.
- CI green, `@codex review`.
- The PR lists recipe counts (122 → 44) and line counts.

## Rollback

Revert the squash commit. The Justfile is not in any system closure, so no host needs a redeploy for a rollback,
except for shipped doc text.
