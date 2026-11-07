---
status: approved
issue: 2750
intent: intent/2026-11-07-2750-gnome-keyring-unlock-queue-abort.md
---

# Spec: stop gnome-keyring aborting when unlock prompts overlap

## Design

A second patch on gnome-keyring 50.0, `overlays/gnome-keyring-unlock-queue.patch`, added to the existing
`gnome-keyring` override in `overlays/upstream-fixes.nix:53` after the #2746 patch. It changes only
`daemon/dbus/gkd-secret-unlock.c`.

The fault is that `unlock_prompt_queue` mixes two things: the one prompt in flight sits at the head, and the prompts
waiting for it sit behind. The code treats "head of the queue" and "queue not empty" as "something is in flight", and
both are wrong once a waiting prompt reaches the head. The patch separates them.

State:

- `static GkdSecretUnlock *unlock_in_flight` holds the prompt whose credential call is running, with its own reference.
- `unlock_prompt_queue` holds only waiting prompts, each with one reference. A prompt is in at most one of the two.
- The async credential call keeps its own reference, as in 50.0.

Changes:

- `perform_next_unlock` returns at once if `self->completed`. On a locked collection: if `unlock_in_flight` is `NULL`, it
  takes a reference into `unlock_in_flight`, sets `current` and starts the call. Otherwise the path goes back on
  `self->queued`, `self` joins the tail of the waiting queue with a new reference unless it is already there, and the
  loop stops.
- `on_unlock_complete` releases `unlock_in_flight` only if it is `self`, and otherwise warns and leaves it alone. Then it
  handles the result:
  - success: as 50.0, then `perform_next_unlock (self)`, which now stops if Dismiss already completed the prompt;
  - `CKR_PIN_INCORRECT`, the user cancelling the dialog: as 50.0, `mark_as_complete (self, TRUE)`;
  - `CKR_CANCEL`: nothing more if `self->completed`, otherwise `mark_as_complete (self, TRUE)`. No early return, so the
    steps below always run;
  - any other error: the warning as now, then `mark_as_complete (self, TRUE)`, so the caller still gets `Completed`.
  It then calls `start_next_waiting ()` and drops the async reference last.
- `start_next_waiting ()`: if a static `draining` flag is set it returns, so nested calls leave the work to the outer
  loop. Otherwise it sets the flag and, while nothing is in flight and the queue is not empty, pops a waiter, calls
  `perform_next_unlock` on it, and then releases the queue's reference, which it held across that call. It clears the
  flag at the end.
- `mark_as_complete` frees `current`, as upstream's `4eacdcf0` does. It removes `self` from the waiting queue if it is
  there, keeping a reference until it returns, and calls `start_next_waiting ()`. It never touches the prompt in flight.

Against the three failures:

| Failure in 50.0 | Why it happens | After the patch |
| --------------- | -------------- | --------------- |
| Abort, issue's stack | `mark_as_complete` pops the head, which is the prompt in flight, and runs it again | The prompt in flight is never in the waiting queue |
| Hang, 3 or more prompts | a woken prompt sees the next waiter, takes it for in flight, waits again | Only `unlock_in_flight` blocks a start |
| Abort on Dismiss in flight | `mark_as_complete` pops `self` and runs it again | Dismiss cancels; the callback frees the slot and wakes the next |

Dismissing the prompt in flight keeps it in `unlock_in_flight` until the cancelled call returns, so a second dialog never
opens over a closing one.

Unchanged from 50.0: a caller that leaves the bus while its prompt waits still gets its turn, and its prompt then runs
with nobody listening. Cancelling waiters on disconnect is a separate change.

## Alternatives rejected

- **Bump to 51.x.** Its only change here, `4eacdcf0`, fixes the Dismiss abort and neither of the other two failures.
- **Upstream's `4eacdcf0` alone, backported.** Same reason. Its one useful line, freeing `current` on completion, is
  carried in this patch.
- **The smallest guard: `mark_as_complete` skips a head whose `current` is set.** It stops the issue's abort but leaves
  the hang, and the hang is the worse failure because nothing logs it.
- **The patch attached to upstream issue 202.** Downloading it needs a GitLab login, so it is unread. Its reporter
  says it is "like 45%" certain. The plan compares it if it can be read.
- **Removing Home Manager's second daemon.** Out of scope, by the owner's decision on the intent.

## Risks

- The patch changes reference ownership in a daemon that holds every secret. A mistake leaks a prompt or frees one in
  use. The lab runs the patched build with `G_DEBUG=fatal-criticals` and checks that every client receives `Completed`;
  neither proves the counts balance, so the Opus and Codex reviews trace each reference against the rules above.
- Both patches rebuild the same derivations as #2746 on p620 and razer, the rebuild scope the owner accepted there. p510
  is not built or deployed without asking.
- A daemon that serves the old build keeps running until the next login, as with #2746.
- If the lab does not reproduce the abort and the hang on 50.0, the reading is wrong. The work stops there and reports,
  without shipping the patch.

## Verification

1. A lab script, `scripts/test-gnome-keyring-unlock-queue.sh`, runs a given `gnome-keyring-daemon` on a private
   `dbus-run-session` with `--auto-start=no`, a throwaway `HOME` and `XDG_*`, and a login collection with a known
   password, and checks that the clients reached the lab daemon. A stub on `org.gnome.keyring.SystemPrompter` holds each
   dialog open until told to answer or cancel it, and reports how many it has seen.
   - **abort**: A prompts and its dialog is held. B gets a prompt for the same collection. The collection is unlocked
     with `UnlockWithMasterPassword`. B calls `Prompt`. 50.0 must abort. The patched build must stay alive, send B
     `Completed`, keep A pending, and send A `Completed` once its dialog is answered.
   - **hang**: A prompts and its dialog is held, B and C prompt and wait. The stub cancels A's dialog, then cancels each
     later dialog as it appears. 50.0 must leave B or C without `Completed` for 10 s with no dialog showing. The patched
     build must show B's and C's dialogs in turn and complete all three.
   - **dismiss**: A prompts and its dialog is held, then A calls `Dismiss`. 50.0 must abort; the patched build must not,
     and a waiting B must then get its dialog.
   - **many**: twenty prompts wait behind A while the collection is unlocked externally, then A's dialog is answered.
     The patched build must complete all of them without aborting.
   - **normal**: one prompt, answered. Both builds must finish.
   Exit codes follow #2746's script: 1 failure seen, 0 none, 2 inconclusive.
2. `just validate`, `just test-host p620` and `just test-host razer` pass.
3. After the next login on each host, the bus name owner runs the new build, and
   `coredumpctl list --since "$START" --no-pager | grep keyring` shows no `perform_next_unlock` abort for 7 days. That
   check joins #2746's step 8 rather than running twice.
4. Upstream issue 202 gets the reproducer and the patch.
