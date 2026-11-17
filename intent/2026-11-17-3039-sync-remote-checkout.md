---
status: approved
issue: 3039
author: olafkfreund
---

# Intent: remotely deployed hosts keep their checkout current

## Problem

A host deployed over SSH from another machine's checkout (razer, p510) never moves its own checkout
(`~/.config/nixos`, which is `/etc/nixos`). Where the build runs does not matter: `just razer` builds on razer,
`deploy-via-p620` builds on p620, and both leave razer's checkout where it was. On 2026-11-17 razer's checkout was
616 commits behind the system it was running, and 22 behind again the same evening. The nightly
`system.autoUpgrade` on razer pulls from GitHub, not from the checkout, so it does not fix this either.

Anything on such a host that reads the local flake reads that stale copy:

- `nixarchy-pkg options refresh` evaluated the old configuration and failed (`cannot coerce a set to a string`).
  It works again after a fast-forward.
- `nixarchy-apply` run on razer would build the old configuration.
- `nixos-rebuild --flake /etc/nixos` on the host itself would roll it back.

## Proposed outcome

After a successful remote deploy of `main`, the target's checkout is fast-forwarded to the `main` commit whose
source was deployed, whenever that is safe. When it is not safe, the deploy prints one line saying why and leaves the
checkout alone. A deploy never fails because of this step.

## Affected users and systems

- Hosts: razer, and p510 when it is deployed (with the owner's OK as always). p620's own checkout is never touched,
  whichever host runs the deploy.
- `Justfile` remote deploy recipes: `razer`, `p510`, `quick-deploy`, `deploy-local-build`, `deploy-via-p620`.
- `scripts/update-commit-deploy.sh` (`nhs` / `update-commit-deploy`) remote path, including its temporary branch,
  squash merge, boot-mode deploys and health-check rollback.
- `docs/UPDATE-DEPLOY.md`.

## Constraints

- Only fast-forward: never reset, rebase, check out, stash or discard anything on the target.
- Only when the target's checkout is on `main` and has no changes.
- Only when the deployed source is known to equal a commit on `origin/main`: the deploying checkout had no
  uncommitted changes, and its tree, captured before the deploy, equals the tree of an `origin/main` commit. This
  also covers `nhs`, whose squash-merged commit has the same tree as the branch it deployed. A feature-branch deploy
  (`ALLOW_BRANCH_DEPLOY=1` with a non-main source) leaves the target alone.
- Only after the final outcome: not when `nhs` rolled the host back, and not when the PR merge failed.
- One extra SSH call per host for the sync (p510 SSH concurrency).
- The guards keep covering everything they cover today. The bus announcement and p510 approval
  (`P510_DEPLOY_APPROVED=1`) stay required for the deploys; the sync must not become a way around the coder guard,
  which blocks `git merge` and the deploy recipes for coder agents.
- Bootloader cleanup (`check-boot-space.sh`'s `switch-to-configuration boot`) is not a deploy and does not sync.

## Open questions

Owner answers (2026-11-17): the recommendations below, all four.

1. When `nhs` or a deploy uses boot mode (always for p510, sometimes as a fallback), sync the checkout at once or
   only after the reboot? Recommended: at once. The checkout should match the generation that will boot, and that
   generation is the default boot entry.
2. When a recipe finds nothing to deploy (`quick-deploy` with an unchanged closure, `nhs` with nothing to update),
   should it still sync a stale checkout? Recommended: yes. It is the cheapest moment to catch a host that is
   already running main.
3. When the sync is unsafe: warn only, or fail? Recommended: warn only.
4. Also report stale checkouts outside a deploy (for example in `just validate`)? Recommended: no. Questions 1 and 2
   cover the deploy paths, and nightly drift is reconciled at the next deploy.
