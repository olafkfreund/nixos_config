---
status: draft
issue: 2750
spec: spec/2026-11-07-2750-gnome-keyring-unlock-queue-abort.md
coders:
  1: codex # the stub prompter speaks gcr's private protocol: small, tricky, and Codex wrote #2746's reproducer
  3: codex # reference ownership in a queue: small tricky logic
  4: coder # one line in an overlay
reviewers:
  - codex # read-only review of the plan, the patch and the PR
---

# Plan: stop gnome-keyring aborting when unlock prompts overlap

agy is left out of `coders:` and `reviewers:`, as the owner decided for #2746 and #2748. Add it back before approving if
wanted.

## Approved decisions

- The fault: `unlock_prompt_queue` in `daemon/dbus/gkd-secret-unlock.c` holds the prompt in flight at its head and the
  waiters behind it, and the code takes "head" and "queue not empty" to mean "in flight". That causes an abort
  (`perform_next_unlock: assertion failed: (!self->current)`), a silent hang with three or more prompts, and an abort when
  the prompt in flight is dismissed.
- The fix is a second patch on 50.0, `overlays/gnome-keyring-unlock-queue.patch`, added to the existing `gnome-keyring`
  override in `overlays/upstream-fixes.nix`. Its rules, copied from the spec:
  - `static GkdSecretUnlock *unlock_in_flight` holds the prompt whose credential call is running, with its own reference.
    `unlock_prompt_queue` holds only waiters, one reference each. A prompt is in at most one of the two. The async call
    keeps its own reference, as in 50.0.
  - `perform_next_unlock` returns at once if `self->completed`. On a locked collection: if `unlock_in_flight` is `NULL`,
    take a reference into it, set `current`, start the call. Otherwise put the path back on `self->queued`, add `self` to
    the tail of the waiting queue with a new reference unless it is already there, and stop.
  - `on_unlock_complete` releases `unlock_in_flight` only if it is `self`, otherwise warns and leaves it. Then: success as
    50.0, then `perform_next_unlock (self)`; `CKR_PIN_INCORRECT` as 50.0; `CKR_CANCEL`: nothing if `self->completed`,
    else `mark_as_complete (self, TRUE)`, with no early return; any other error: the warning, then
    `mark_as_complete (self, TRUE)`. Then `start_next_waiting ()`, then drop the async reference last.
  - `start_next_waiting ()` returns if a static `draining` flag is set. Otherwise it sets the flag and, while nothing is in
    flight and the queue is not empty, pops a waiter, calls `perform_next_unlock` on it and releases the queue's
    reference after that call returns. It clears the flag at the end.
  - `mark_as_complete` frees `current` (as upstream's `4eacdcf0`), removes `self` from the waiting queue if it is there,
    keeping a reference until it returns, and calls `start_next_waiting ()`. It never touches the prompt in flight.
  - Unchanged: a caller that leaves the bus while waiting still gets its turn.
- Rejected: a bump to 51.x and a backport of `4eacdcf0` alone (both fix the Dismiss abort only); a guard that skips a head
  with `current` set (leaves the hang); removing Home Manager's second daemon (out of scope, owner's decision).
- Stop rule: if the lab cannot make 50.0 abort and hang, the reading is wrong. Stop and report; ship nothing.
- p620 and razer rebuild the same derivations as #2746, which the owner accepted. p510 is not built or deployed without
  asking.

## Deviations from the spec

- **The lab runs inside a Nix build sandbox, not on the host's session.** During #2746, lab runs on p620 were followed by
  unexplained stops of the real daemon, and the lead stopped running aborting labs there. A sandboxed build has no real
  bus, home or keyring to reach, which is stronger isolation than a private bus with throwaway directories.
- **The "normal" and "abort" scenarios cancel A's dialog rather than answer it.** Answering needs gcr's secret exchange
  in the stub. Cancelling exercises the same queue code; a successful unlock is covered by the external
  `UnlockWithMasterPassword` in "abort" and "many".

## Steps

1. **Lab.** Create `scripts/test-gnome-keyring-unlock-queue.nix` and `scripts/test-gnome-keyring-unlock-queue.py`.
   - The `.nix` file takes `{ keyring, scenario }` and imports the flake's p620 `pkgs`
     (`(builtins.getFlake (toString ../.)).nixosConfigurations.p620.pkgs`). It is a `runCommand` with `dbus`, `keyring`
     and `python3.withPackages (ps: [ ps.dbus-next ])`. It runs the `.py` under `dbus-run-session`, with `HOME` and
     `XDG_*` in the build directory, and writes the scenario's result line and exit code to `$out`. It must not fail
     when the scenario finds the bug, because that is the expected result on 50.0.
   - The `.py` starts `gnome-keyring-daemon --start --foreground --components=secrets` from `keyring`, and checks with
     `GetConnectionUnixProcessID` that `org.freedesktop.secrets` is that daemon. It creates a `login` collection through
     `org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface.CreateWithMasterPassword` on a `plain` session, then
     locks it.
   - It registers a stub `org.gnome.keyring.SystemPrompter` that holds each dialog until told to cancel it, and counts
     the dialogs it has seen. Read the `gcr` version in `keyring`'s build inputs for the protocol (`gcr-system-prompt.c`,
     `gcr-system-prompter.c`, `org.gnome.keyring.Prompter.xml`).
   - Scenarios, each with a 10 s bound per wait: `abort`, `hang`, `dismiss`, `many` (20 waiters) and `normal`, as the
     spec's verification lists them, with the deviation above. Result: `ABORT`, `HANG`, `OK` or `INCONCLUSIVE`, with
     the exit codes 1, 1, 0 and 2. `OK` requires every client's `Completed`.
   - Check: `python3 -m py_compile`, `nixpkgs-fmt --check`, and step 2.
   - Traps: `builtins.getFlake` sees only tracked files, so `git add` both before building. Never run the lab on the
     host's session bus. Use `--auto-start=no` on every `dbus-send` or `busctl` call.
2. **Gate on 50.0 (lead).** Build each scenario against the current 50.0 with #2746's patch,
   `nix eval --raw .#nixosConfigurations.p620.pkgs.gnome-keyring.outPath`, using `nix-build --check` on reruns. Expected:
   `abort` and `dismiss` give `ABORT`, `hang` gives `HANG`, `normal` gives `OK`. `many` is recorded without a
   requirement. If `abort` or `hang` is not reproduced, stop under the stop rule, comment on the issue and tell the
   owner. Record the build times, because sandboxed aborts still reach `coredumpctl`.
3. **Patch.** Create `overlays/gnome-keyring-unlock-queue.patch` against the 50.0 tarball's
   `daemon/dbus/gkd-secret-unlock.c`, implementing the rules above and nothing else. Generate it with `diff -u` from an
   unpacked copy (`nix-build -A` or `nix build` of `gnome-keyring.src`), never by hand. It must apply with `patch -p1`
   after the #2746 patch.
   - Check: `patch -p1 --dry-run` on a fresh unpack with both patches.
   - Traps: the Write formatter strips tabs in markdown, so never paste the patch into a markdown file.
4. **Overlay.** In `overlays/upstream-fixes.nix:53-55`, append `./gnome-keyring-unlock-queue.patch` to the `patches`
   list after the #2746 patch, and extend the comment above it to name #2750.
   - Check: `nixpkgs-fmt --check overlays/upstream-fixes.nix`, `statix check`, `deadnix`.
5. **Lab on the patched build (lead).** Build the patched `gnome-keyring` and run all five scenarios with
   `G_DEBUG=fatal-criticals` set in the lab daemon's environment. Every scenario must give `OK`.
6. **Commit and PR (lead).** Commit steps 1 to 4 by path, naming the steps and who did them. Run `just validate`,
   `just test-host p620` and `just test-host razer`. Push, and confirm the remote head matches. Open a PR linking the
   intent, spec and plan, then comment `@codex review`. Run a fresh Opus review given only this plan and `git diff`, and
   have it trace each reference against the rules above. Fix confirmed findings, update this plan for any deviation in
   the same commit, and merge when CI and both reviews are clean.
7. **Deploy (lead).** Read and post on `#agents:freundcloud.org.uk`, then `AGENT_BUS_ANNOUNCED=1 just p620`, then
   `just deploy-via-p620 razer`. The nightly upgrade would also deliver it, but an explicit deploy gives a known time.
   Ask the owner to log out and in on each host, then confirm that the owner of `org.freedesktop.secrets` runs the new
   store path and that `timeout 10 gh auth status` succeeds.
8. **Watch (lead).** Join #2746's step 8: from the moment the new daemon owns the bus name on p620, run
   `coredumpctl list --since "$START" --no-pager | grep keyring` for 7 days, counting `perform_next_unlock` aborts
   separately. Exclude the lab build times recorded in steps 2 and 5.
9. **Upstream (lead).** Draft a comment for GNOME GitLab issue 202 with the reproducer and the patch, and give it to
   the owner to post, because this session has no GitLab login. Close #2750 after step 8 passes.

## Tests

| Command | Expected |
| ------- | -------- |
| lab, 50.0, `abort` / `dismiss` / `hang` / `normal` | `ABORT` / `ABORT` / `HANG` / `OK` |
| lab, patched, all five scenarios | `OK` |
| `just validate`, `just test-host p620`, `just test-host razer` | pass |
| `coredumpctl list --since "$START" --no-pager \| grep keyring`, 7 days | no `perform_next_unlock` |

## Rollback

Remove `./gnome-keyring-unlock-queue.patch` from the `patches` list in `overlays/upstream-fixes.nix` and redeploy; the
# 2746 patch stays. A host keeps the patched daemon until its next login.
