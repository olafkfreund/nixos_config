---
status: approved
issue: 3039
spec: spec/2026-11-17-3039-sync-remote-checkout.md
coders:
  1: codex # small, tricky shell: tree matching, remote fast-forward safety, and its test suite
  2: coder # mechanical Justfile wiring
  3: codex # nhs exit paths under set -euo pipefail are easy to get subtly wrong
  4: coder # guard pattern and test lines
  5: coder # docs
reviewers:
  - codex # independent read of the diff against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: remotely deployed hosts keep their checkout current

Branch `fix/3039-sync-remote-checkout`, worktree `~/.config/nixos-shelfish`.

## Approved decisions (from the spec)

- New `scripts/sync-remote-checkout.sh`, never fails a deploy; every problem prints one line
  `checkout sync (HOST): <reason>`.
- `around HOST -- COMMAND…`: before COMMAND, record the source in a variable: eligible only when
  `git status --porcelain` is empty and the checkout is on `main` or detached exactly at `origin/main`; source =
  `git rev-parse HEAD^{tree}`. Run COMMAND, keep its exit code; only on exit 0 and eligible run `sync`; otherwise
  print the reason. Exit with COMMAND's code.
- `sync HOST TREE`: skip when HOST is `p620` or `$(hostname)`. `git fetch -q origin main`; newest commit in
  `git log --first-parent -n 500 --format='%H %T' origin/main` whose tree equals TREE; none → skip. One call
  `ssh HOST bash -s -- COMMIT` with a fixed stdin script, in `~/.config/nixos`: not on branch `main` → skip;
  `git status --porcelain --ignored=no` not empty → skip; `git fetch -q origin`; HEAD = COMMIT → "already current";
  `git merge-base --is-ancestor HEAD COMMIT` fails → skip; else
  `git merge --ff-only --no-overwrite-ignore --no-autostash -q COMMIT` → "fast-forwarded OLD..NEW (N commits)".
  SSH or remote failure → "could not sync: …". Always exit 0. No reset, checkout, stash or rebase.
- Justfile: wrap the remote activation lines; `quick-deploy`'s no-change branch runs `around HOST -- true`.
- nhs, remote mode only and never with `--no-deploy`: `DEPLOYED_TREE` set right before the remote activation; sync
  after step 12 only with no PR, or merge succeeded and local `main` fast-forwarded; sync at the nothing-to-do exit
  with `HEAD^{tree}`. Rollback and `--no-deploy` paths never sync. Boot mode syncs at once.
- Coder guard blocks any command whose text contains `sync-remote-checkout`.
- Existing guard gaps (`bash scripts/update-commit-deploy.sh p510` passes the bus/p510 guards; `just --dry-run
  razer` blocked) → a separate issue, opened by the lead in step 6.

## Steps

- **Step 1:** `scripts/sync-remote-checkout.sh` and `scripts/test-sync-remote-checkout.sh` (new, both executable,
  `#!/usr/bin/env bash`, `set -uo pipefail` in the script, no `-e` around the steps that may fail).
  - The script as decided above. The remote part is a quoted heredoc passed on stdin (`ssh "$HOST" bash -s --
    "$commit" <<'REMOTE'`); it uses only `$1` and never interpolates local values into the remote text.
  - The test builds, in a temp dir: a bare `origin`, a deploying clone `src` and a target clone at
    `$tmp/home/.config/nixos`; a fake `ssh` first on `PATH` that removes only the HOST argument and runs the
    remaining argv as is (`HOME=$tmp/home "$@"`, already `bash -s -- COMMIT`) with stdin; a `hostname` stub
    returning `testhost`. Cases (each asserts the target
    HEAD and the printed line): `around` with a failing COMMAND → its exit code, no ssh (fake ssh writes a marker);
    `around` on clean `main` whose COMMAND itself commits to the source and pushes a newer `origin/main` →
    target at the tree recorded before COMMAND, not the new HEAD and not past it; dirty source; feature branch;
    feature branch whose tree equals a `main` commit → skipped;
    `sync` with a squash-merge commit's tree → target at the squash commit; `main` moved before the squash (tree
    not on main) → skipped; dirty target; target on another branch; target with a local commit → skipped and
    unchanged; ignored file in the target at a path the new commit tracks (add the path to the target's
    `.git/info/exclude`) → not overwritten, line says it could not sync; `merge.autostash=true` in the target
    plus a fake `git` wrapper that edits a tracked file after the cleanliness check → no stash created, edit
    intact, merge refused; fake ssh exiting 255 → exit 0;
    HOST `p620` and HOST `testhost` → no ssh.
  Check: `bash scripts/test-sync-remote-checkout.sh` passes; `shellcheck` on both files is clean; break one case on
  purpose (drop `--no-overwrite-ignore`, then `--no-autostash`) and see the test fail each time, then restore.
  Traps: bus guard matches command text (deploy/switch words): write prose and test data without them where
  possible, and run checks from files; `git` in the test needs `user.name`/`user.email` set per repo; no network.

- **Step 2:** `Justfile`.
  - Lines 279 (`razer`), 290 (`p510`), 429 (`deploy-local-build`) and 462 (`deploy-via-p620`'s `else` branch):
    prefix the `nixos-rebuild switch …` command with `./scripts/sync-remote-checkout.sh around <HOST> --` (literal
    `razer`/`p510` or `{{HOST}}`), keeping every argument. Line 460 (self-deploy) is not wrapped.
  - Line 391 (`quick-deploy` no-change branch): after the echo, `./scripts/sync-remote-checkout.sh around {{ HOST }}
    -- true; \`.
  - Line 164 (`test-guards`): add `@bash ./scripts/test-sync-remote-checkout.sh`,
    `@bash ./scripts/test-nhs-checkout-sync.sh` (from step 3) and `@bash ./modules/programs/claude-coder-guard.test.sh`.
  Check: `just --list` and `just check-syntax` work. From a file (the bus guard blocks that text), `just --dry-run`
  for `razer`, `p510`, `deploy-local-build x`, `deploy-via-p620 x` and `quick-deploy x`, with the output grepped:
  each remote activation is wrapped with the right host, every original argument is still there, the self-deploy
  branch is not wrapped, and the no-change branch has the `around … -- true` call. `just test-guards` passes
  (after step 4).
  Traps: Justfile recipe lines with `\` continuations need the `;` before `\`; keep the `# Guarded by name
  (#2951)` comments; the bus/p510 guards must still fire on `just razer`/`just p510` (they match recipe names).

- **Step 3:** `scripts/update-commit-deploy.sh`.
  - Line 274 (nothing-to-do): before `exit 0`, when `[ "$MODE" = remote ] && [ "$NO_DEPLOY" -eq 0 ]`:
    `"$REPO_ROOT/scripts/sync-remote-checkout.sh" sync "$HOST" "$(git rev-parse 'HEAD^{tree}')" || true` (use the
    script's existing repo-root variable or `$(git rev-parse --show-toplevel)`).
  - Line 675 (remote activation): immediately before the `if ! nh_switch_or_boot … --target-host` line,
    `DEPLOYED_TREE=$(git rev-parse 'HEAD^{tree}')`.
  - Step 12 (lines 745–768) and the no-PR case: after the `if [ -n "${PR_URL:-}" ]` block, sync when
    `MODE=remote` and either there was no PR or `MERGED=1`: `… sync "$HOST" "$DEPLOYED_TREE" || true`, skipped
    when `DEPLOYED_TREE` is empty. Initialise `MERGED=0` and `DEPLOYED_TREE=""` explicitly near the other state
    variables (an inherited value must not count); set `MERGED=1` only right after the successful
    `ok "lock landed …"` at line 767. The merge-failure branch never sets it.
  - The sync command is `"${NHS_SYNC_CMD:-$REPO_ROOT/scripts/sync-remote-checkout.sh}"`, so a test can record calls.
  - `scripts/test-nhs-checkout-sync.sh` (new, run by `just test-guards`): runs the script in a temp clone with stub
    `nh`, `gh`, `ssh`, `nix`, `nixos-rebuild` and health check on `PATH` and `NHS_SYNC_CMD` pointing at a recorder.
    Paths: remote no-PR success → one `sync HOST <tree>` with the pre-activation tree; lock change with merge and
    pull success → one call with the pre-activation tree; nothing-to-do → one call with HEAD's tree; boot-mode
    success → one call; activation failure and health-check failure (rollback) → no call; both `--no-deploy` exits
    → no call; local mode → no call; merge failure → no call; pull failure → no call; recorder exiting 1 → the
    script's own exit code unchanged. If stubbing a path proves impractical, report it; the lead decides and
    updates this plan.
  Check: `bash -n` and shellcheck clean; `bash scripts/test-nhs-checkout-sync.sh` passes; break the `MERGED`
  condition on purpose and see it fail, then restore.
  Traps: `set -euo pipefail` in this script: guard every new command with `|| true`; `DEPLOYED_TREE` must be set
  on every remote path that reaches step 12 (default it to empty at the top and skip the sync when empty).

- **Step 4:** `modules/programs/claude-coder-guard.sh` and its test.
  - Near the top, after the command text is read and before per-command parsing: if the whole command text
    contains `sync-remote-checkout`, `block "remote checkout sync (part of a deploy)"`.
  - `claude-coder-guard.test.sh`: add to the BLOCK list `./scripts/sync-remote-checkout.sh sync razer abc`,
    `bash scripts/sync-remote-checkout.sh around razer -- true` and `just status _x sync-remote-checkout`.
  Check: `bash modules/programs/claude-coder-guard.test.sh` passes; `just test-host p620` builds (the guard is
  packaged in `claude-code-managed.nix`).
  Traps: the guard is a Nix-substituted script (`@jq@`); keep that; the test runs it with `jq` substituted.

- **Step 5:** `docs/UPDATE-DEPLOY.md`: a "Remote checkout sync" section after "Remote host requirements"
  (line 128): what moves, the skip reasons, that it never fails a deploy, and the manual equivalent in a `bash`
  fence. Check: markdownlint (pre-push), no line starting `#` plus a digit, lines ≤ 120.

- **Step 6 (lead):** run all checks; open the separate issue for the existing guard gaps; bus `read_new` + `post`;
  `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer` from this branch with `ALLOW_BRANCH_DEPLOY=1`: the sync must
  skip with "not on main" (feature-branch case, live). After merge, from a clean `main` worktree detached at
  `origin/main`: the same deploy fast-forwards razer's checkout to that commit; a second run prints "already
  current". Commit per step, PR linking intent, spec and plan (who did which step), Opus review of the diff, Codex
  review, `@codex review`.

Deviation (step 3, recorded at commit): two existing shellcheck findings in
`scripts/update-commit-deploy.sh` were fixed alongside (an SC2029 disable comment and one quoted `date -d`
argument), so the file is shellcheck-clean.

Deviation (after the Opus review, recorded at commit): the sync's ssh call gets `BatchMode`, a 10 s connect
timeout and a 120 s overall `timeout`, the remote git runs with `GIT_TERMINAL_PROMPT=0`, and the remote script is
wrapped in a function; `around` re-checks the source after COMMAND and skips if it changed; nhs records a tree only
from a clean checkout (a staged `flake.lock` is deployed but is not HEAD's tree). Tests added for detached HEAD,
an edit during COMMAND, nothing-to-do with `--no-deploy`, and a staged lock. Docs note that exit 4 skips the sync.

## Tests

- `just test-guards` (now also the sync, nhs-sync and coder-guard suites); `just check-syntax`.
- `bash -n` and shellcheck on the changed scripts; `just test-host p620`.
- Step 6's live checks on razer.

## Rollback

Revert the PR. Recipes run `nixos-rebuild` directly again, `nhs` stops syncing, the guard drops the pattern.
Checkouts already fast-forwarded stay where they are, which is harmless.
