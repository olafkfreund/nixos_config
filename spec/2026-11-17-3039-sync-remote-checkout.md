---
status: draft
issue: 3039
intent: intent/2026-11-17-3039-sync-remote-checkout.md
---

# Spec: remotely deployed hosts keep their checkout current

## Design

One new script, `scripts/sync-remote-checkout.sh`, with two subcommands, called from the remote deploy paths.

### `sync-remote-checkout.sh source HOST`

Run before the deploy, in the deploying checkout. Writes one line to `$XDG_RUNTIME_DIR/nixos-deploy-source.HOST`
(fallback `/tmp/nixos-deploy-source.$UID.HOST`): the tree id of `HEAD` (`git rev-parse HEAD^{tree}`) when
`git status --porcelain` is empty, otherwise the word `dirty`. Recording the tree, not the commit, is what lets the
`nhs` squash merge match: the squashed `main` commit has the same tree as the branch commit that was deployed.

### `sync-remote-checkout.sh sync HOST`

Run after the deploy succeeds. Always exits 0 and prints one line starting `checkout sync (HOST):`. Steps, each
stopping with a one-line reason:

1. Skip when HOST is `p620` or this machine's hostname (local deploy; the shared checkout is never touched).
2. Read and delete the source file. Missing → skip ("no recorded source"); `dirty` → skip ("deployed from a dirty
   checkout").
3. `git fetch -q origin main`, then find the newest commit on `origin/main`'s first-parent history (last 500)
   whose tree equals the recorded one. None → skip ("deployed source is not on origin/main", which covers feature
   branch deploys).
4. One SSH call: `ssh HOST bash -s -- COMMIT` with a fixed script on stdin. On the host, in `~/.config/nixos`:
   on branch `main` (else skip), `git status --porcelain` empty (else skip), `git fetch -q origin`; already at
   COMMIT → "already current"; `git merge-base --is-ancestor HEAD COMMIT` fails → skip ("checkout has commits not in
   main"); otherwise `git merge --ff-only -q COMMIT` → "fast-forwarded OLD..NEW (N commits)".
5. SSH or remote failure → "could not sync: …".

No `reset`, `checkout`, `stash` or `rebase` anywhere.

### Justfile

- Two private recipes: `_deploy-source HOST` and `_sync-checkout HOST`, each one line calling the script.
- `razer`, `p510`, `deploy-local-build` and `deploy-via-p620` gain `(_deploy-source HOST)` as a dependency and
  `&& (_sync-checkout HOST)` as a subsequent dependency. Just runs subsequent dependencies only after the recipe body
  succeeds, so a failed deploy never syncs. Boot-mode is not used by these recipes.
- `quick-deploy` gains `(_deploy-source HOST)`. Its deploy branch calls `just HOST`, which syncs itself; its
  "no changes" branch calls `scripts/sync-remote-checkout.sh sync HOST` (intent answer 2).
- The `# Guarded by name (#2951)` comments stay with their recipes.

### `nhs` (`scripts/update-commit-deploy.sh`)

`nhs` already refuses a dirty tree and deploys from `main` or its own lock branch. Remote mode only:

- Nothing-to-do exit (step 6): call `source` then `sync` before `exit 0` (intent answer 2).
- After step 12: when there was no PR (the deploy was from `main`) or the squash merge succeeded and local `main`
  was fast-forwarded, call `source` then `sync`. The recorded tree is `main`'s, equal to the deployed branch's.
  Merge failed → no sync (the warning already printed says the lock is not on `main`).
- Rollback paths (`rollback_and_close_pr`) exit before step 12, so they never sync.
- Boot mode (p510 always, others as fallback): the sync still runs at once (intent answer 1).
- `--no-deploy` exits before any of this.

### Guards

- `modules/programs/claude-coder-guard.sh` blocks `_sync-checkout`, `_deploy-source` and
  `sync-remote-checkout` for coder agents, next to the deploy recipes it already blocks (the script runs a
  `git merge` on another host).
- The bus guard is unchanged: the sync runs inside deploys that already need `AGENT_BUS_ANNOUNCED=1`, and
  `P510_DEPLOY_APPROVED=1` stays required for p510. The sync itself is not a disruptive operation.
- `scripts/check-boot-space.sh` is not touched.

### Docs

`docs/UPDATE-DEPLOY.md`: a short "Remote checkout sync" section: what moves, when it is skipped and why, and the
manual equivalent (`git -C ~/.config/nixos merge --ff-only origin/main` on the host).

## Alternatives rejected

- **Pull `origin/main` on the target instead of the deployed commit:** the checkout could get ahead of what runs.
- **Compare commits instead of trees:** never matches after an `nhs` squash merge.
- **`git reset --hard` or `checkout` on the target:** destroys local work; the intent allows fast-forward only.
- **Sync from a systemd timer on each host:** another moving part; fixes drift the deploy step already covers
  (intent answer 4).
- **Fail the deploy when the sync is unsafe:** the system is already switched; failing then only confuses
  (intent answer 3).
- **A just variable evaluated at startup for the source:** would run `git status` on every `just` invocation.

## Risks

- **A shared checkout on the target that someone is editing:** a dirty tree is skipped; a clean tree on `main` is
  only fast-forwarded, which another agent's work there survives (nothing to lose).
- **p510:** the sync adds one SSH call after the deploy; p510 is still only deployed with the owner's OK.
- **The source file outliving a run:** `sync` deletes it; a stale file from a crashed run is overwritten by the
  next `source`. A deploy that crashes between the two leaves it; the next deploy overwrites it.
- **500-commit window:** a source older than 500 first-parent commits on `main` is reported as "not on
  origin/main" and skipped. Harmless.
- **Bus guard false positives:** the new recipe and script names contain no guarded words; checked by
  `just test-guards`.

## Verification

- `scripts/test-sync-remote-checkout.sh` (new, run by `just test-guards`): temp bare origin plus a deploying clone
  and a target clone, a fake `ssh` on `PATH` that runs the stdin script with `HOME` pointed at the target. Cases:
  target behind → fast-forwarded to the deployed commit (not past it); squash-merged source → fast-forwarded to the
  squash commit; dirty target, target on another branch, target with local commits → skipped, unchanged; dirty
  source, source not on `origin/main`, missing source file → skipped; `ssh` failing → exit 0; HOST equal to the
  local hostname or `p620` → skipped without calling `ssh`.
- `just test-guards` passes (bus guard, p510 guard and the coder guard with the new names).
- `just --evaluate` and `just --list` still work; `just check-syntax`.
- Live: `just deploy-via-p620 razer` from a clean `main`, announced on the bus; razer's checkout ends at the
  deployed commit and the recipe prints the sync line. A second run prints "already current".
