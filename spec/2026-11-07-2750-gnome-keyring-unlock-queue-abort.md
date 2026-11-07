---
status: draft
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
both are wrong once a waiting prompt reaches the head. The patch separates them:

- A static `GkdSecretUnlock *unlock_in_flight` holds the prompt whose credential call is running, with a reference.
  `unlock_prompt_queue` holds only waiting prompts.
- `perform_next_unlock`, on a locked collection: if `unlock_in_flight` is `NULL`, it becomes `self`, the credential call
  starts and `current` is set. Otherwise the path goes back on `self->queued`, `self` joins the tail of the waiting queue
  if it is not already in it, and the loop stops.
- `on_unlock_complete` clears `unlock_in_flight` first, warning if it is not `self`, then handles the result as now, then
  calls a new `start_next_waiting ()` if nothing is in flight.
- `start_next_waiting ()` pops waiting prompts and calls `perform_next_unlock` on each until one is in flight or the queue
  is empty.
- `mark_as_complete` takes `self` out of the waiting queue if it is there, and calls `start_next_waiting ()` if nothing
  is in flight. It never touches the prompt in flight.

What this changes, against the three failures:

| Failure in 50.0 | Why it happens | After the patch |
| --------------- | -------------- | --------------- |
| Abort, issue's stack | `mark_as_complete` pops the head, which is the prompt in flight, and runs it again | The prompt in flight is never in the waiting queue |
| Hang with 3 or more prompts | a woken prompt sees the next waiter, thinks it is in flight, waits again | Only `unlock_in_flight` blocks a start |
| Abort on Dismiss of the prompt in flight | `mark_as_complete` pops `self` and runs it again | Dismiss cancels the call; its callback clears `unlock_in_flight` and wakes the next |

Dismissing the prompt in flight keeps it marked in flight until the cancelled call returns, so a second dialog never
opens over a closing one.

## Alternatives rejected

- **Bump to 51.x.** Its only change here, `4eacdcf0`, fixes the Dismiss abort and neither of the other two failures.
- **Upstream's `4eacdcf0` alone, backported.** Same reason.
- **The smallest guard: `mark_as_complete` skips a head whose `current` is set.** It stops the issue's abort but leaves
  the hang, and the hang is the worse failure because nothing logs it.
- **The patch attached to upstream issue 202.** Downloading it needs a GitLab login, so it is unread. Its reporter says it
  is "like 45%" certain. The plan compares it if it can be read.
- **Removing Home Manager's second daemon.** Out of scope, by the owner's decision on the intent.

## Risks

- The patch changes queue ownership in a daemon that holds every secret. A reference-count mistake leaks a prompt or
  frees one in use. The lab runs each patched scenario with `G_DEBUG=fatal-criticals`, so a critical warning aborts, and
  checks that every client receives `Completed`.
- Both patches rebuild the same derivations as #2746 on p620 and razer, the rebuild scope the owner accepted there. p510 is
  not built or deployed without asking.
- A daemon that serves the old build keeps running until the next login, as with #2746.
- If the lab does not reproduce the abort and the hang on 50.0, the reading is wrong. The work stops there and reports,
  without shipping the patch.

## Verification

1. A lab script, `scripts/test-gnome-keyring-unlock-queue.sh`, runs a given `gnome-keyring-daemon` on a private
   `dbus-run-session` with `--auto-start=no`, a throwaway `HOME` and `XDG_*`, and a login collection with a known password.
   It checks the clients reached the lab daemon. A stub on `org.gnome.keyring.SystemPrompter` holds a prompt open, or
   cancels it, as each scenario needs.
   - **abort**: A prompts and is held. B gets a prompt for the same collection. The collection is unlocked with
     `UnlockWithMasterPassword`. B calls `Prompt`. 50.0 must abort; the patched build must stay alive and send both
     `Completed` signals.
   - **hang**: A prompts and is held, B and C prompt and wait, then A's prompt is cancelled. 50.0 must leave B or C without
     `Completed` past a 10 s bound; the patched build must finish all three.
   - **dismiss**: A prompts and is held, then calls `Dismiss`. 50.0 must abort; the patched build must not.
   - **normal**: one prompt, answered. Both builds must finish.
   Exit codes follow #2746's script: 1 failure seen, 0 none, 2 inconclusive.
2. `just validate`, `just test-host p620` and `just test-host razer` pass.
3. After the next login on each host, the bus name owner runs the new build, and
   `coredumpctl list --since "$START" --no-pager | grep keyring` shows no `perform_next_unlock` abort for 7 days. That
   check joins #2746's step 8 rather than running twice.
4. Upstream issue 202 gets the reproducer and the patch.
