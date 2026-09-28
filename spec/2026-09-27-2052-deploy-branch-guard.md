---
status: approved
issue: 2052
intent: intent/2026-09-27-2052-deploy-branch-guard.md
---

# Spec: an unmerged branch cannot reach a host by accident

The intent was approved on 2026-09-27 with the recommended answers:

| # | Question | Decision |
| --- | --- | --- |
| 1 | The nixarchy paths (rebuild button, `nixarchy-apply`) | File a nixarchy issue as part of this task: text only, no nixarchy code. The user may overrule this in review |
| 2 | Hook door | An explicit override, `SHARED_CHECKOUT_BRANCH_OK=1`, like `P510_DEPLOY_APPROVED=1`. It asserts that the user asked for it |
| 3 | `git checkout <file>` | Stays allowed. Only branch changes are blocked |

**A correction to the intent:** it said `nhs`'s check would "become the
shared one". It won't. `nhs` refuses a non-main branch for a different reason:
it bumps the lock and merges to main, so it must **never** run on a branch,
even with an override. Its check at `scripts/update-commit-deploy.sh:89-100`
stays exactly as it is. The new guard is for the plain deploy recipes, where
an override is legitimate.

## Design

### 1. `Justfile`: one private guard recipe, a dependency of every activating recipe

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

`_require-main` is added as a dependency (`recipe ARGS: _require-main`) of
every recipe that activates a system:
`deploy`, `p620`, `razer`, `p510`, `deploy-fast`, `deploy-local-build`,
`deploy-via-p620`, `deploy-cached`, `emergency-deploy` and `deploy-smart`.
Those recipes were listed from the `Justfile` on 2026-09-27 by matching
`nixos-rebuild … switch|boot|test`, `nh os switch|boot|test` and
`switch-to-configuration`. `quick-deploy` (through `deploy-smart`) and
`deploy-all-parallel` (through `p620`/`razer`/`p510`) are covered through
the recipes they call. Build-only recipes (`test-host`, `quick-test`,
`build-*`) are not touched, so building a branch still works.

A detached HEAD counts as "not main", which covers a worktree left detached.

### 2. Claude Code: a PreToolUse hook blocks branch changes in the shared checkout

A new `sharedCheckoutGuardScript` in `modules/programs/claude-code-managed.nix`
follows the shape of `deployGuardScript`: it reads the command from the hook
payload, exits 2 to deny, and lets a stated override through. It is wired as
`sharedCheckoutGuardHooks` behind a new `cfg.sharedCheckoutGuard.enable`
option, which defaults to true like the other guards.

- **The target repo** is the `-C <dir>` argument if one is given, otherwise
  the payload's `cwd`. The guard acts only when that path, resolved with
  `realpath`, is `~/.config/nixos` (so `/etc/nixos` counts too).
- **Blocked:**
  - `git switch <anything>` other than `git switch main`
  - `git checkout -b/-B/--orphan/--detach …`
  - `git checkout <arg>` with no `--`, where `<arg>` resolves to a branch or
    commit (`git rev-parse --verify --quiet "<arg>^{commit}"`) and is not
    `main`
  - `gh pr checkout …`
- **Allowed:**
  - switching to `main`
  - `git checkout -- <paths>`, and `git checkout <path>` where `<path>` is not
    a ref
  - `git worktree add …`, and every read-only git command
- **Override:** `SHARED_CHECKOUT_BRANCH_OK=1` in the command. The message
  explains that the override asserts that the user asked for it, and says to
  use a worktree otherwise.

### 3. `AGENTS.md`: the rule for every agent

Under **Git**, add:

> Never check out a branch in `~/.config/nixos`. It is `/etc/nixos`, so every
> deploy builds whatever it has checked out. Do branch work in a
> `git worktree` (`git worktree add ../nixos-<issue> -b <branch> origin/main`)
> and leave the shared checkout on `main`. Claude Code enforces this with a
> PreToolUse hook; other agents must follow it themselves.

The `Justfile` guard backs this up for every agent, because it applies
whoever runs the recipe.

### 4. The nixarchy issue (decision 1)

File one issue on `olafkfreund/nixarchy`: the rebuild button and
`nixarchy-apply` build from `NIXARCHY_FLAKE` (`/etc/nixos`) whatever branch
it is on. Suggest the same branch check with an override, and link #2052.
No nixarchy code changes.

## Alternatives rejected

- **Point `/etc/nixos` at a separate clone that only tracks main:** theme
  switching and `nixarchy-apply` write into that tree, so their edits would
  land away from where the user commits.
- **Reuse `nhs`'s check for plain deploys:** `nhs` must never allow an
  override (see the correction above). Different jobs need different guards.
- **Block in NixOS activation:** a flake build doesn't know its branch
  (`self` has `rev`/`dirtyRev`, not a branch name), so activation can't tell.
- **Hard-block branch changes with no override:** the user sometimes asks
  for exactly this. The p510 guard's reasoning applies: a guard with no door
  gets worked around.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| The hook blocks a legitimate `git checkout <file>` | Claude sessions | Tests H5–H6. A file restore that isn't a ref is allowed |
| The hook matches prose that mentions `git switch` (like the bus guard) | Claude sessions | It acts only on a real command in the shared checkout; H8 checks that prose in `echo`/`--body-file` passes |
| `just` dependency order: the guard runs after a `set`/confirm prompt | Justfile | Dependencies run before the recipe body. J1–J4 check the order |
| The deploy that ships the hook also rolls out #2051 (`hypr-rdp`, merged 2026-09-27 20:22, `output = "DP-1"` mirror mode) to p620 for the first time | p620 | Watch `hypr-rdp` `NRestarts` for 60 s after the switch. If it loops, runtime-mask it, report on the bus and to the user, and don't roll back the guard |
| p510 is left without the hook | p510 | It gets it at its next approved deploy. The `Justfile` guard applies there at once |

## Verification

**Justfile** (in a worktree):

| # | Case | Expected |
| --- | --- | --- |
| J1 | `just _require-main` on `main` | exit 0, prints `>> deploying main @ <rev>` |
| J2 | `just _require-main` on a branch | exit 1, names the branch and the override |
| J3 | `ALLOW_BRANCH_DEPLOY=1 just _require-main` on a branch | exit 0 |
| J4 | `just --dry-run p620` on a branch | stops at `_require-main` and never prints `nixos-rebuild` |
| J5 | `just --summary` lists every recipe from §1 with the dependency | yes |

**Hook** (the script run with a JSON payload, `cwd` set to the shared checkout):

| # | Command | Expected |
| --- | --- | --- |
| H1 | `git switch feat/x` | blocked |
| H2 | `git -C ~/.config/nixos checkout -b fix/y` | blocked |
| H3 | `git checkout 4f4673dc8` | blocked (commit) |
| H4 | `gh pr checkout 2051` | blocked |
| H5 | `git checkout -- flake.lock` | allowed |
| H6 | `git checkout flake.lock` | allowed (not a ref) |
| H7 | `git switch main`; `git worktree add ../x -b y origin/main` | allowed |
| H8 | `echo "never git switch here"`; the same command with `cwd` = a worktree | allowed |
| H9 | `SHARED_CHECKOUT_BRANCH_OK=1 git switch feat/x` | allowed |

**System:**

- `just check-syntax`; `just test-host p620`; `just test-host razer`;
  evaluate p510 only.
- After deploying p620 and razer (bus-announced): check that
  `/etc/claude-code/managed-settings.json` lists the new hook, and repeat H1
  live in a Claude session.
- `hypr-rdp` on p620: `NRestarts` stays at 0 for 60 s (the #2051 risk).
