---
status: approved
issue: 2750
spec: spec/2026-11-07-2750-gnome-keyring-unlock-queue-abort.md
coders:
  1: codex # the stub prompter speaks gcr's private protocol and secret exchange: small, tricky
  3: codex # reference ownership in a queue: small tricky logic
  4: coder # one line in an overlay
reviewers:
  - codex # read-only review of the plan, the patch and the PR, tracing every reference
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
  - `on_unlock_complete` releases `unlock_in_flight` only if it is `self`, otherwise warns and leaves it. Then: success
    as 50.0, then `perform_next_unlock (self)`; `CKR_PIN_INCORRECT` as 50.0; `CKR_CANCEL`: nothing if
    `self->completed`, else `mark_as_complete (self, TRUE)`, with no early return; any other error: the warning, then
    `mark_as_complete (self, TRUE)`. Then `start_next_waiting ()`, then drop the async reference last.
  - `start_next_waiting ()` returns if a static `draining` flag is set. Otherwise it sets the flag and, while nothing is
    in flight and the queue is not empty, pops a waiter, calls `perform_next_unlock` on it and releases the queue's
    reference after that call returns. It clears the flag at the end.
  - `mark_as_complete` frees `current` (as upstream's `4eacdcf0`), removes `self` from the waiting queue if it is there,
    keeping a reference until it returns, and calls `start_next_waiting ()`. It never touches the prompt in flight.
  - Unchanged: a caller that leaves the bus while waiting still gets its turn.
- Rejected: a bump to 51.x and a backport of `4eacdcf0` alone (both fix the Dismiss abort only); a guard that skips a
  head with `current` set (leaves the hang); removing Home Manager's second daemon (out of scope, owner's decision). The
  patch attached to upstream issue 202 is compared if it becomes readable without a login.
- Stop rule: if the lab cannot make 50.0 abort and hang, the reading is wrong. Stop and report; ship nothing.
- p620 and razer rebuild the same derivations as #2746, which the owner accepted. p510 is not built or deployed without
  asking. `just validate` (`nix flake check`) only evaluates p510.

## Deviation from the spec

The lab runs inside a Nix build sandbox, not on the host's session. During #2746, lab runs on p620 were followed by
unexplained stops of the real daemon, and the lead stopped running aborting labs there. A sandboxed build has no real
bus, home or keyring to reach, and runs as a `nixbld` user, which is stronger isolation than a private bus with
throwaway directories.

**Step 1 as done, 2026-11-07.** Codex wrote the lab. `hang` gives B and C separate locked collections,
because with one collection B's unlock also satisfies C and C's dialog never appears; 50.0 still
hangs. The lead fixed four faults found in step 2: `dbus-run-session` needs `--config-file` in the
sandbox, the dbus-next flag is `NO_AUTOSTART`, secret byte arrays must be `bytes`, and the stub
ignores a failed `PromptDone`, as gcr's prompter does. The lab is committed before step 3, because
`agent-run` needs a clean worktree.

**Step 2 gate, 2026-11-07 09:31 to 09:32 GMT, passed.** On 50.0 with #2746's patch
(`cfi2q33b`): `abort` and `dismiss` give `ABORT` on `gkd-secret-unlock.c:243`, `hang` gives
`HANG`, and `normal` and `many` give `OK`. The reading of the cause holds.

## Steps

Work only in the worktree `~/.config/nixos-2750` on `fix/2750-gnome-keyring-unlock-queue-abort`. Never check out a
branch in `~/.config/nixos`.

1. **Lab.** Create three files.
   - `scripts/test-gnome-keyring-unlock-queue.py`, the lab client:
     - Starts `gnome-keyring-daemon --start --foreground --components=secrets` from the given store path, with its stderr
       to a log, and checks with `GetConnectionUnixProcessID` that `org.freedesktop.secrets` is that daemon. It runs
       without capabilities; a warning about locked memory is expected.
     - Creates a `login` collection with a known password through
       `org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface.CreateWithMasterPassword` on a `plain` session, then
       locks it with `Lock`.
     - Registers a stub `org.gnome.keyring.SystemPrompter` that records each dialog and, on command, answers it with the
       password or cancels it. Answering uses gcr's secret exchange. Read the protocol from the `gcr` in the daemon's
       build inputs: `gcr-system-prompt.c`, `gcr-system-prompter.c`, `gcr-secret-exchange.c` and the prompter XML.
     - Uses `dbus-next` only, and passes `--auto-start=no` semantics by never auto-starting names.
     - Runs one scenario with a 10 s bound on each wait. The assertions per scenario:
       - `abort`: A prompts and its dialog is held. B gets a prompt for `login`. `login` is unlocked with
         `UnlockWithMasterPassword`. B calls `Prompt`. Patched: the daemon lives, B gets `Completed` while A's dialog is
         still open, then the stub answers A and A gets `Completed` with `dismissed=false`.
       - `hang`: A prompts and is held, B and C prompt. The stub cancels A's dialog, then answers each later dialog.
         Patched: B's and C's dialogs appear one after the other, never two at once, and all three get `Completed`.
       - `dismiss`: A prompts and is held, B prompts and waits, A calls `Dismiss`. Patched: the daemon lives, A gets
         `Completed` with `dismissed=true`, and B's dialog then appears and is answered.
       - `many`: 20 prompts wait behind A, `login` is unlocked externally, then the stub answers A. Patched: all 21 get
         `Completed`, and only A's dialog ever appears.
       - `normal`: one prompt, answered. Both builds: `Completed` with `dismissed=false` and `login` unlocked.
     - Prints one line, `result=ABORT|HANG|OK|INCONCLUSIVE`. `ABORT` needs the daemon to have died by SIGABRT with
       `perform_next_unlock` or `!self->current` in its log. `HANG` needs the daemon alive, no dialog open and a
       `Completed` missing after the bound. `OK` needs every assertion above. Anything else is `INCONCLUSIVE`. It kills
       its children before exiting.
   - `scripts/test-gnome-keyring-unlock-queue.nix`, taking `{ nixpkgs, keyring, scenario, nonce }`. `nixpkgs` is the
     path of the flake's nixpkgs, `keyring` a store path turned into a dependency with `builtins.storePath`, and `nonce`
     a string that forces a fresh build. It is a `runCommand` with `dbus`, `python3.withPackages (ps: [ ps.dbus-next ])`
     and the `.py` file referenced as `${./test-gnome-keyring-unlock-queue.py}`. It creates `HOME` and an
     `XDG_RUNTIME_DIR` with mode 0700 in the build directory, runs the client under `dbus-run-session`, prints the
     daemon log to the build log, and writes only the result line to `$out`, so the build succeeds whatever the result.
   - `scripts/test-gnome-keyring-unlock-queue.sh`, the runner: `test-... <keyring-store-path> <expect-file>`, where the
     expect file lists `scenario result` pairs. For each scenario it runs `nix-build` with
     `--arg nixpkgs "$(nix eval --raw .#nixosConfigurations.p620.pkgs.path)"`, `--argstr keyring`, `--argstr scenario`
     and `--argstr nonce "$(date +%s%N)"`, reads `$out`, and prints each scenario with its result. It exits 0 when every
     result matches, 1 on a mismatch, 2 on any `INCONCLUSIVE`. A failed `nix-build` counts as `INCONCLUSIVE`, never as a
     result.
   - Checks: `python3 -m py_compile`, `nixpkgs-fmt --check`, `shellcheck` with no findings (info level included), then
     step 2.
   - Traps: never run the client on the host's session bus. The Bash tool's stdin is a socket, so run with `</dev/null`.
     Pre-push lints whole files.
2. **Gate on 50.0 (lead).** Realise the current package first, `nix build --no-link --print-out-paths
   .#nixosConfigurations.p620.pkgs.gnome-keyring`, and keep that path. Run the runner with an expect file of
   `abort ABORT`, `dismiss ABORT`, `hang HANG`, `normal OK`. `many` is run too and its result recorded without an
   expectation. If `abort` or `hang` does not match, stop under the stop rule: comment on the issue and tell the owner.
   Record each run's time.
3. **Patch.** Create `overlays/gnome-keyring-unlock-queue.patch` against the 50.0 tarball's
   `daemon/dbus/gkd-secret-unlock.c`, implementing the rules above and nothing else. Generate it with `diff -u` from an
   unpacked copy of `gnome-keyring.src`, never by hand.
   - Check: on a fresh unpack, `patch -p1 --dry-run` applies the #2746 patch, then this one.
   - Traps: the Write formatter strips tabs in markdown, so never paste the patch into a markdown file.
4. **Overlay.** In `overlays/upstream-fixes.nix:53-55`, append `./gnome-keyring-unlock-queue.patch` to the `patches`
   list after the #2746 patch, keeping it, and extend the comment above to name #2750.
   - Check: `nixpkgs-fmt --check overlays/upstream-fixes.nix`, `statix check`, `deadnix`.
   - Trap: flakes ignore untracked files, so `git add` the patch before building.
5. **Lab on the patched build (lead).** Realise the patched package the same way, then run the runner with every
   scenario expected `OK` and `G_DEBUG=fatal-criticals` in the lab daemon's environment. Record each run's time.
6. **Commit and PR (lead).** Commit steps 1 to 4 by path, naming the steps and who did them. Run `just validate`,
   `just test-host p620` and `just test-host razer`. Push, and confirm the remote head matches. Open a PR linking the
   intent, spec and plan, then comment `@codex review`. Run a fresh Opus review given only this plan and `git diff`.
   Both reviews trace each reference against the rules above. Fix confirmed findings, update this plan for any deviation
   in the same commit as the code, and merge when CI and both reviews are clean.
7. **Deploy (lead).** On merged `main`: read `#agents:freundcloud.org.uk`, and wait if anyone has a job in flight. Post
   the plan, then `AGENT_BUS_ANNOUNCED=1 just p620`. Do the same again for `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620
   razer`. Ask the owner to log out and in on each host. Then, on each host, confirm the PID owning
   `org.freedesktop.secrets` runs the new store path, record that time as the host's `START`, and check that
   `timeout 10 gh auth status` succeeds.
8. **Watch (lead).** Join #2746's step 8, on p620 and on razer, from each host's `START`, for 7 days. List keyring dumps
   with `coredumpctl list --since "$START" --no-pager | grep keyring`, keep only UID 1000 (lab builds run as `nixbld`),
   and classify each with `coredumpctl info <PID>`: `perform_next_unlock` aborts count for this issue, `open_session`
   aborts for #2746. Count outside stops of the unit separately, as #2746 does.
9. **Upstream (lead).** Draft a comment for GNOME GitLab issue 202 with the reproducer and the patch, and give it to the
   owner to post, because this session has no GitLab login. Close #2750 once step 8 passes and the owner has posted the
   comment or declined to.

## Tests

| Command | Expected |
| ------- | -------- |
| runner, 50.0: `abort` / `dismiss` / `hang` / `normal` | `ABORT` / `ABORT` / `HANG` / `OK`, runner exit 0 |
| runner, patched, all five scenarios | `OK`, runner exit 0 |
| `just validate`, `just test-host p620`, `just test-host razer` | pass |
| step 8 on p620 and razer, 7 days | no UID 1000 `perform_next_unlock` abort |

## Rollback

Remove `./gnome-keyring-unlock-queue.patch` from the `patches` list in `overlays/upstream-fixes.nix`, keeping the patch
from the earlier issue. Run `just test-host p620` and `just test-host razer`, then deploy as in step 7, with the bus
announcement, `just p620` and `just deploy-via-p620 razer`. A host keeps the patched daemon until its next login;
confirm the bus name owner afterwards.
