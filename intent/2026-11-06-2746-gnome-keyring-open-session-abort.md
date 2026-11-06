---
status: approved
issue: 2746
author: olafkfreund
---

# Intent: Stop gnome-keyring crashes from locking the keyring

## Problem

`gnome-keyring-daemon` 50.0 aborts repeatedly on p620: 5 core dumps from 3 to
6 November 2026, two of them on the 6th. Each crash loses the login unlock,
because PAM only unlocks the keyring at login. systemd brings up a replacement
daemon, and that one is locked.

On 6 November the replacement also stopped starting `gcr-prompter`. Unlock
requests returned prompt objects, but no password dialog appeared, so
`gh auth status` hung in `keyring.Get` with no output and nothing to answer.
Stopping the daemon's unit and asking again was the only recovery found. It
needs someone to know that recipe.

Evidence for the abort, from the journal and the 50.0 source:

- Before each abort the daemon logs
  `gkd_secret_service_get_pkcs11_session: assertion 'client' failed`, then
  `aes_negotiate: assertion 'session' failed`, then GLib's fatal
  `g_variant_new: expected GVariant of type 'v' but received value has type '(null)'`.
- `service_method_open_session` in `daemon/dbus/gkd-secret-service.c` only
  checks `error`. `aes_negotiate` and `plain_negotiate` can both fail without
  setting one, so a NULL output reaches
  `gkd_exported_service_complete_open_session`. Only the AES path has been seen
  to crash here.
- The `'client'` assertion means the daemon had no record of the caller. It
  removes a record when that client leaves the bus, so a client disconnecting
  mid-call is one possible trigger. This is inferred: no disconnect has been
  observed, and the client is unknown.

Fedora crash reports show the same stack on 46.x and 48.x. No upstream fix was
found, but upstream's git history has not been checked.

## Proposed outcome

- A failed `OpenSession` negotiation, on either algorithm, returns a D-Bus error
  to the caller and the daemon keeps running with its unlock intact.
- A repeatable check reproduces the failure: it aborts the unpatched daemon and
  not the patched one.
- `coredumpctl` shows no `gnome-keyring` aborts with this signature on p620 for
  7 days after deploying. There were 5 in the 4 days before.

This does not promise the keyring never locks or never prompts. Those symptoms
may have other causes, covered by the open questions below.

## Affected users and systems

- p620: the only host with these crashes. razer and p510 show no keyring core
  dumps in the last 14 days.
- Keyring clients on p620: `gh`, `secret-tool` users, and any other Secret
  Service client.
- razer and p510 run the same package source, so they have the same bug even
  though it has not fired there.

## Constraints

- Must not change or migrate the keyring files in `~/.local/share/keyrings/`.
- Must not move tokens out of the keyring as the fix.
- p510 is never built or deployed without asking first.
- Rebuild cost matters: an overlay on a widely used package can miss the binary
  cache, so what it rebuilds must be measured.
- Deploying follows the agent bus rule.

## Open questions

1. Which hosts should get the fix: p620 only, or all three? The bug is present
   on all of them. Recommendation: p620 first, then razer, and p510 only when
   you ask.
2. Nine unlock prompts started on p620 on 6 November, but only two crashes
   happened. Something else may also be locking the keyring. Should this task
   explain those prompts, or only stop the crash? Recommendation: include finding
   the cause in this task, and open a separate issue if the fix is different.
3. The missing password dialog was seen once, after one crash, and its cause is
   unknown. Stopping the crash should stop this path to it, but that is not
   proven. Is that enough for now? Recommendation: yes, and reopen this if it
   happens without a crash.
