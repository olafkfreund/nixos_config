---
status: draft
issue: 3165
author: olafkfreund
---

# Intent: per-plugin startup timing for the Omarchy shell

## Problem

After #3147 the login cover still stays up about 7 s after the bars map, so
the login intro plays under it and is never seen. The Omarchy shell's main
loop is busy for about 4 s after `Configuration Loaded` (issue 3165, p620
login 2026-11-21 08:47).

What has been ruled out: the plugin registry scan (one `find`) and QML
compilation (about 1 s in total, spread thin, panels already load
asynchronously). What is left is object creation and startup work of the
loaded set: about 30 bar widgets on two monitors, the plugin services and the
`keepLoaded` overlays. The shell log has one-second resolution and no
per-plugin timing, so we cannot tell which of these costs the time.

## Proposed outcome

One login on p620 produces a table: for every bar widget, plugin service and
panel or overlay loader, the millisecond time it started and finished
loading. From that table we pick what to cut or defer in a follow-up change
(that fix is not part of this task).

## Affected users and systems

- p620 only, for the measurement login. razer gets nothing new.
- The Omarchy shell from nixarchy (`omarchy-shell`), patched locally in this
  repo for the measurement; no change in the nixarchy repo is needed for the
  measurement itself.
- The startup probe (`~/.local/share/startup-probe`) stays as it is.

## Constraints

- Temporary and easy to remove: the patch is off unless an environment
  variable is set, and the revert is a single commit.
- Logging must not change load order or timing in a way that hides the cost
  (no synchronous file writes per event; use the shell's own log).
- No change to what plugins load or how they behave.
- p510 is untouched. Deploy p620 only, with the bus announcement first.
- Needs one logout and login by the owner to collect the data.

## Open questions

- Patch the shell through an overlay in this repo (fast, p620 only), or as a
  gated PR to nixarchy so it is available on every host? Recommendation: an
  overlay here; upstream nothing until we know it is worth keeping.
- If no single plugin stands out, do the microVM clean-vs-ours bisect next,
  as already agreed in the issue.
