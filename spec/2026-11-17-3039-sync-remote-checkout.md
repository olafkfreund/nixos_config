---
status: approved
issue: 3039
intent: intent/2026-11-17-3039-sync-remote-checkout.md
---

# Spec: remotely deployed hosts keep their checkout current

## Design

One new script, `scripts/sync-remote-checkout.sh`, with two subcommands. It never makes a deploy fail: every
problem in it prints one line starting `checkout sync (HOST):` and is otherwise ignored.

### `sync-remote-checkout.sh around HOST -- COMMAND…` (the Justfile recipes)

Wraps the activation command of a remote recipe, in one process, so no state has to pass between recipes or
runs (two deploys at once can't mix up their sources):

1. **Record the source before COMMAND runs**, in a shell variable: eligible only when the deploying checkout has
   no changes (`git status --porcelain` empty) and is on `main`, or detached exactly at `origin/main` (the same
   rule as `_require-main`). Then the source is `HEAD^{tree}`. Otherwise the reason is kept ("dirty checkout",
   "not on main", which covers `ALLOW_BRANCH_DEPLOY=1` feature-branch deploys).
2. Run COMMAND and keep its exit code.
3. Only when COMMAND exited 0 and the source is eligible: run `sync` (below). Otherwise print the reason.
4. Exit with COMMAND's exit code, so the recipe behaves exactly as before.

### `sync-remote-checkout.sh sync HOST TREE` (also called directly by `nhs`)

1. Skip when HOST is `p620` or this machine's hostname (local deploy; the shared checkout is never touched).
2. `git fetch -q origin main`, then find the newest commit in the last 500 of `origin/main`'s first-parent
   history whose tree equals TREE. None → skip ("deployed source is not on origin/main").
3. One SSH call: `ssh HOST bash -s -- COMMIT` with a fixed script on stdin. On the host, in `~/.config/nixos`:
   - not on branch `main` → skip;
   - `git status --porcelain --ignored=no` not empty → skip;
   - `git fetch -q origin`;
   - HEAD is already COMMIT → "already current";
   - `git merge-base --is-ancestor HEAD COMMIT` fails → skip ("checkout has commits not in main");
   - otherwise `git merge --ff-only --no-overwrite-ignore --no-autostash -q COMMIT` → "fast-forwarded OLD..NEW
     (N commits)". `--no-overwrite-ignore` stops an ignored local file being replaced by a newly tracked one;
     `--no-autostash` stops a config setting from stashing edits that appear after the check.
4. SSH or remote failure → "could not sync: …". Exit 0 in every case.

No `reset`, `checkout`, `stash` or `rebase` anywhere.

### Justfile

- `razer`, `p510`, `deploy-local-build`: the `nixos-rebuild switch …` line becomes
  `./scripts/sync-remote-checkout.sh around HOST -- nixos-rebuild switch …` (same arguments).
- `deploy-via-p620`: only the remote `switch` line in its `else` branch is wrapped; the self-deploy branch is not.
- `quick-deploy`: the deploy branch calls `just HOST`, which syncs. The "no changes" branch runs
  `./scripts/sync-remote-checkout.sh around HOST -- true` (intent answer 2: a host already running the build
  still gets its checkout synced; the eligibility rules still apply).
- The `# Guarded by name (#2951)` comments stay with their recipes. The bus and p510 guards match the command text,
  which still contains `nixos-rebuild switch` and the host, so they keep firing.

### `nhs` (`scripts/update-commit-deploy.sh`)

`nhs` refuses a dirty tree and starts on `main`. Remote mode only, never with `--no-deploy`:

- **Record before activation:** right before the remote `nh_switch_or_boot` call (after the lock commit, on the
  lock branch or on `main`), set `DEPLOYED_TREE=$(git rev-parse HEAD^{tree})`.
- **After step 12**, call `sync HOST "$DEPLOYED_TREE"` (failure ignored) only when: there was no PR (deployed from
  `main`), or the squash merge succeeded and local `main` was fast-forwarded. After a squash merge, the squash
  commit's tree equals `DEPLOYED_TREE` only when `main` did not move in between; if it moved, no commit matches and
  the sync is skipped. Commits merged by others are never claimed as deployed. Merge failed → no sync.
- **Nothing-to-do exit (step 6)**, when `MODE=remote` and `NO_DEPLOY=0`: call `sync HOST "$(git rev-parse
  HEAD^{tree})"` before `exit 0` (intent answer 2; the host already runs this tree).
- Rollback paths (`rollback_and_close_pr`) and both `--no-deploy` exits never reach a sync call.
- Boot mode (p510 always, others as fallback): the sync still runs right after a successful deploy (intent
  answer 1).

### Guards

- `modules/programs/claude-coder-guard.sh`: block any command whose text contains `sync-remote-checkout`,
  whatever the interpreter or position (`bash scripts/…`, `./scripts/…`, `just x …`), with the same hand-back
  message as the deploy recipes. Name-only blocking misses `bash scripts/sync-remote-checkout.sh` and later
  `just` arguments. Test cases go in `modules/programs/claude-coder-guard.test.sh`.
- The bus guard and p510 guard are unchanged (see Justfile). `P510_DEPLOY_APPROVED=1` stays required for p510.
- Already-existing guard gaps Codex found (`bash scripts/update-commit-deploy.sh p510` passes the bus and p510
  guards; `just --dry-run razer` is blocked) go into a separate issue, not this change.
- `scripts/check-boot-space.sh` is not touched.

### Docs

`docs/UPDATE-DEPLOY.md`: a short "Remote checkout sync" section: what moves, when it is skipped and why, and the
manual equivalent (`git -C ~/.config/nixos merge --ff-only origin/main` on the host).

## Alternatives rejected

- **Pull `origin/main` on the target instead of the deployed source:** the checkout could get ahead of what runs.
- **Compare commits instead of trees:** never matches after an `nhs` squash merge.
- **Record the source in a file between a "before" and an "after" recipe:** two deploys at once mix up their
  sources, and a failed write can fail the deploy (review finding).
- **Record the source after the `nhs` merge:** the pulled `main` can include commits that were never deployed
  (review finding).
- **`git reset --hard` or `checkout` on the target:** destroys local work; the intent allows fast-forward only.
- **Sync from a systemd timer on each host:** another moving part (intent answer 4).
- **Fail the deploy when the sync is unsafe:** the system is already switched (intent answer 3).

## Risks

- **A target checkout someone is editing:** a dirty tree is skipped; a clean tree on `main` is only fast-forwarded,
  ignored files are never overwritten, and nothing is stashed.
- **`main` moved during an `nhs` run:** no matching tree, so the sync is skipped with a reason; the next deploy
  catches up.
- **p510:** one extra SSH call after the deploy; p510 is still deployed only with the owner's OK.
- **The wrapper changes recipe exit codes:** it must return COMMAND's code exactly; tested.
- **500-commit window:** an older source is reported as "not on origin/main" and skipped. Harmless.

## Verification

- `scripts/test-sync-remote-checkout.sh` (new, run by `just test-guards`). Temp bare origin, a deploying clone and
  a target clone; a fake `ssh` on `PATH` runs the stdin script with `HOME` set so `~/.config/nixos` is the target.
  - `around`: COMMAND fails → exit code passed through, no `ssh` call; COMMAND succeeds on clean `main` → target
    fast-forwarded to the deployed commit, not past newer `origin/main` commits; dirty source, feature branch,
    feature branch whose tree also exists on `main` → skipped, target unchanged.
  - `sync`: squash-merged tree → fast-forwarded to the squash commit; `main` moved before the squash → skipped;
    dirty target, target on another branch, target with local commits → skipped and unchanged; an ignored file in
    the target at a path the new commit tracks → merge refused, file intact; `ssh` failing → exit 0; HOST equal
    to `p620` or the local hostname → no `ssh` call.
- `nhs`: each exit path reviewed against the list above, plus `bash -n` and shellcheck; live check below.
- `modules/programs/claude-coder-guard.test.sh`: the new block for `./scripts/…`, `bash scripts/…` and
  `just status _x sync-remote-checkout` forms; `just test-guards` also runs it.
- `just check-syntax`; `just --list` still works.
- Live, announced on the bus: `just deploy-via-p620 razer` from a clean `main`; razer's checkout ends at the
  deployed commit and the recipe prints the sync line; a second run prints "already current".
