---
status: approved
issue: 2750
author: olafkfreund
---

# Intent: stop gnome-keyring aborting when unlock prompts overlap

## Problem

`gnome-keyring-daemon` 50.0 aborted three times on p620 on 2026-11-06, at 17:03:43, 17:03:53 and 17:17:09, with:

```text
ERROR:../daemon/dbus/gkd-secret-unlock.c:243:perform_next_unlock: assertion failed: (!self->current)
```

An abort takes the login keyring with it. PAM unlocks the keyring only at login, so the next daemon starts locked, every
client asks for an unlock at once, and those overlapping requests are what this bug seems to need. This makes the failure
in the #2746 issue worse, and #2746's patch does not touch this code.

The cause, from reading the source, not yet reproduced: an unlock prompt in flight stays at the head of
`unlock_prompt_queue` with `current` set. If another client's `Prompt` has nothing left to unlock, it goes straight to
`mark_as_complete`, which pops that in-flight prompt and calls `perform_next_unlock` on it, so the assertion fails.

The same queue can also hang without any error, again from reading the source. With prompts A, B and C queued, A's
completion pops B, B sees C still queued, re-queues itself behind C and starts nothing, so no operation is left to advance
either of them. This might explain the hangs in #2746 where `gh` waited and no password dialog appeared, which is
unproven.

In 50.0, dismissing a prompt in flight reaches the same assertion by another path. Upstream's `4eacdcf0` fixes that one.

Upstream issue 202 on GNOME's GitLab, open since 2026-10-21, shows the same assertion. Its backtrace has two different
objects in the positions this reading predicts, and its reporter's Evolution starts four unlock requests at login. The
only related upstream fix, `4eacdcf0` in 51.0, covers dismissing a prompt, not this case, so a version bump would not
solve it.

## Proposed outcome

- Overlapping unlock requests no longer abort or hang the daemon. Every request, three or more at once included, gets its
  own `Completed` signal within a bounded wait, and a prompt in flight still finishes.
- Both failures are reproduced in the lab, with the abort and the hang before the fix and neither after. This is what tests
  the reading above: if it does not reproduce, the cause is wrong and this task stops to say so.
- The upstream issue hears what we found.

## Affected users and systems

- p620 and razer, which already run a patched gnome-keyring from #2746, so another patch on the same package adds no new
  rebuild scope.
- p510 also uses gnome-keyring, is still on the unpatched build, and is built or deployed only when the owner agrees.
- Anything that reads secrets from the keyring: `gh`, browsers, mail.

## Constraints

- Reproduce only on a private bus with `--auto-start=no` and disposable `HOME` and `XDG_*` directories, checking that the
  clients reach the lab daemon, never the real one. Lab runs on p620 add core dumps and may have disturbed the real daemon
  during #2746.
- Carry the smallest patch that works, as an overlay beside the one from #2746, and drop it once upstream ships a fix.
- Do not change how the keyring is started in this task.

## Open questions

1. Should this task also remove the second daemon? Home Manager's `gnome-keyring.service` (`services.gnome-keyring.enable`
   in `home/desktop/gnome/default.nix:75`) runs beside the daemon that owns the bus name on p620, razer included. Nothing
   ties it to these crashes yet, so the recommendation is to leave it out and open a separate issue.
2. Why the daemon's unit was stopped from outside at 16:16:06, 16:44:17 and 17:02:42 stays unexplained. No agent command
   or user shell history matches, and none has happened since the lab runs ended. The recommendation is to stop looking
   unless it recurs; #2746's step 8 already counts stops as their own category.
