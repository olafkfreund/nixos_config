---
status: draft
issue: 3039
author: olafkfreund
---

# Intent: remotely deployed hosts keep their checkout current

## Problem

razer and p510 are built elsewhere and switched over SSH, so their own checkout (`~/.config/nixos`, which is
`/etc/nixos`) never moves. On 2026-11-17 razer's was 616 commits behind the system it was running, and 22 behind
again the same evening.

Anything on such a host that reads the local flake reads that stale copy:

- `nixarchy-pkg options refresh` evaluated the old configuration and failed (`cannot coerce a set to a string`).
  It works again after a fast-forward.
- `nixarchy-apply` run on razer would build the old configuration.
- `nixos-rebuild --flake /etc/nixos` on the host itself would roll it back.

## Proposed outcome

After a deploy from p620 to a remote host, that host's checkout points at the commit that was deployed, whenever
it is safe to move. When it is not safe, the deploy says why and leaves the checkout alone. A deploy never fails
because of this step.

## Affected users and systems

- Hosts: razer, and p510 when it is deployed (with the owner's OK as always). p620 is deployed locally from its own
  checkout and is not affected.
- `Justfile` remote deploy recipes: `razer`, `p510`, `quick-deploy`, `deploy-local-build`, `deploy-via-p620`, and
  the remote path of `nhs` / `update-commit-deploy`.
- `docs/UPDATE-DEPLOY.md`.

## Constraints

- Only fast-forward: never reset, rebase, check out or discard anything on the remote host.
- Only when the remote checkout is on `main`, has no changes, and the deployed commit is on `origin/main`. A
  branch deploy (`ALLOW_BRANCH_DEPLOY=1`) must leave it alone.
- Never on p620 itself (shared checkout, other sessions work there).
- One SSH call per host, after the switch (p510 SSH concurrency).
- The command text must not trip the bus guard or the coder guard.

## Open questions

1. Fast-forward to the deployed commit, or to `origin/main`? Recommended: the deployed commit, so the checkout
   matches what runs.
2. When unsafe (dirty, other branch, branch deploy): warn only, or also fail? Recommended: warn only.
3. Also add a check (for example in `just validate` or a timer) that reports hosts whose checkout is behind?
   Recommended: no, the deploy step is enough.
