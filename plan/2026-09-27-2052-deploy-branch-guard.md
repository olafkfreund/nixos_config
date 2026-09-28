---
status: draft
issue: 2052
spec: spec/2026-09-27-2052-deploy-branch-guard.md
---

# Plan: an unmerged branch cannot reach a host by accident

Branch `fix/2052-deploy-branch-guard`, in the worktree
`scratchpad/nixos-2052`. The shared checkout is never touched.

## Approved decisions

These are carried over from the spec.

**D1. The `Justfile` guard.** A private recipe, `_require-main`, near the
top of the `Justfile`:

```just
# Refuse to activate anything built from a branch other than main.
_require-main:
    #!/usr/bin/env bash
    set -euo pipefail
    branch=$(git branch --show-current)
    rev=$(git rev-parse --short HEAD)
    if [ "$branch" != "main" ] && [ "${ALLOW_BRANCH_DEPLOY:-}" != "1" ]; then
      echo "!! refusing to deploy from '${branch:-detached HEAD}' ($rev), not main" >&2
      echo "   /etc/nixos is this checkout; deploying a branch ships it to the host." >&2
      echo "   switch back:     git switch main && git pull --ff-only" >&2
      echo "   deploy it anyway: ALLOW_BRANCH_DEPLOY=1 just <recipe>" >&2
      exit 1
    fi
    echo ">> deploying ${branch:-detached HEAD} @ $rev"
```

It is added as a dependency of exactly these ten recipes (line numbers
from 2026-09-28): `deploy` (12), `razer` (483), `p620` (487), `p510` (491),
`emergency-deploy HOST` (914), `deploy-fast HOST` (1030),
`deploy-local-build HOST` (1035), `deploy-smart HOST` (1040),
`deploy-cached HOST` (1059), `deploy-via-p620 HOST` (1064). Each header
becomes `<name> [HOST]: _require-main`. Build-only recipes are left alone.

**D2. The Claude hook.** `sharedCheckoutGuardScript` in
`modules/programs/claude-code-managed.nix`, built like `deployGuardScript`
(line 268):

- It reads `.tool_input.command` and `.cwd` from the payload.
- The target repo is `-C <dir>` if present, otherwise `cwd`, resolved with
  `realpath -m`. The guard acts only when the target equals
  `realpath ~/.config/nixos`.
- **Blocked:**
  - `git switch X`, where X is not `main`
  - `git checkout` with `-b`, `-B`, `--orphan` or `--detach`
  - `git checkout X` with no `--`, where
    `git -C <repo> rev-parse --verify --quiet "X^{commit}"` succeeds and X is
    not `main`
  - `gh pr checkout …`
- **Override:** the command contains `SHARED_CHECKOUT_BRANCH_OK=1`. Denial
  exits 2 with a message naming the worktree command and the override.
- It is wired as `sharedCheckoutGuardHooks` (PreToolUse, matcher `Bash`)
  behind a new `sharedCheckoutGuard.enable` option, default `true`, declared
  next to `deployGuard.enable` (line 661). It is added to the
  `lib.zipAttrsWith` list at line 577.

**D3. `AGENTS.md`.** Under `## Git` (line 124), add the paragraph from spec
§3 verbatim.

**D4. The nixarchy issue.** One issue on `olafkfreund/nixarchy`, text only,
linking #2052. Its body is written to a file and passed with `--body-file`.

**D5. `nhs` is not changed.** `scripts/update-commit-deploy.sh:89-100`
keeps its no-override refusal.

## Steps

1. **Rebase** onto `origin/main` (2 commits behind on 2026-09-28).
   → verify: the recipe line numbers in D1 still match. If they don't,
   update D1 in this file in the step-2 commit.
2. **`Justfile`** (D1).
   → verify: J1–J5 from the Tests table, run in this worktree. It is on a
   branch, so J2–J4 are live. J1 runs from a throwaway worktree on `main`.
3. **`claude-code-managed.nix`** (D2).
   → verify: `just check-syntax`. Build the script
   (`nix build .#nixosConfigurations.p620.config.environment.etc."claude-code/managed-settings.json".source`,
   then read the hook path from it) and run H1–H9 with synthetic payloads
   `{"tool_input":{"command":…},"cwd":…}`.
4. **`AGENTS.md`** (D3).
   → verify: markdownlint is clean.
5. **Build:** `just test-host p620`, `just test-host razer`, and evaluate
   p510's managed settings only.
   → verify: all pass. The p620 `managed-settings.json` lists the new hook.
6. **Commit** as `fix(deploy): refuse branch deploys and branch checkouts in the shared checkout (#2052)`,
   push, and open a PR that links the intent, spec and plan.
7. **File the nixarchy issue** (D4), and add its link to the PR.
8. **Merge** when CI is green (squash, `--match-head-commit`). Then
   fast-forward the shared checkout, which is on `main`, so the `Justfile`
   and `AGENTS.md` take effect at once.
9. **Deploy the hook to p620** from main with `just quick-deploy p620`,
   bus-announced. `_require-main` passes on main, and J1 is proven live.
   razer follows when the bus shows it free (there's a user reservation
   today). p510 is not deployed.
   → verify: the S tests.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| J1 | `just _require-main` in a worktree on `main` | exit 0, `>> deploying main @ <rev>` |
| J2 | `just _require-main` on this branch | exit 1, message names the branch and `ALLOW_BRANCH_DEPLOY` |
| J3 | `ALLOW_BRANCH_DEPLOY=1 just _require-main` | exit 0 |
| J4 | `just --dry-run p620` on this branch | fails at `_require-main`; `nixos-rebuild` never printed |
| J5 | `just --show <each of the 10>` | shows `_require-main` as a dependency |
| H1–H9 | the spec's hook table, with `cwd=/home/olafkfreund/.config/nixos` unless noted | as in the spec |
| S1 | p620 after deploy: `jq '.hooks.PreToolUse[].hooks[].command' /etc/claude-code/managed-settings.json` | includes the shared-checkout guard |
| S2 | p620: `systemctl --failed`, `systemctl --user --failed`, and `hypr-rdp` `NRestarts` stable for 60 s | 0 / 0 / no growth |

## Rollback

- **Before merge:** close the PR. Nothing is deployed before step 9.
- **After merge:** `git revert` the step-6 commit. The `Justfile` and
  `AGENTS.md` revert at once. Redeploy p620 (and razer if done) to drop the
  hook. Or turn the hook off without a revert:
  `modules.programs.claude-code-managed.sharedCheckoutGuard.enable = false`
  (the option from D2).
- **Emergency bypass at any time:** `ALLOW_BRANCH_DEPLOY=1` for the `Justfile`
  guard, and `SHARED_CHECKOUT_BRANCH_OK=1` for the hook.
