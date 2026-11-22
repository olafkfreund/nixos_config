---
status: approved
issue: 3165
author: olafkfreund
---

# Intent: per-plugin startup timing for the Omarchy shell

## Problem

After #3147 the login cover still stays up about 7 s after the bars map, so
the login intro plays under it and is never seen. The Omarchy shell's main
loop is busy for about 4 s after `Configuration Loaded` (issue 3165, p620
login 2026-11-21 08:47).

The 7.2 s has two parts that need separate answers:

- 50.96 → 55.08 (about 4.1 s): the main loop is blocked, from
  `Configuration Loaded` until owed's IPC call, `idle` and `polkit` are answered.
- 55.08 → about 58.0 (about 2.9 s): the loop is free again, but
  `desktopReady` (`BackgroundIntro.qml`: no plugin reload or registry scan
  running, and the bar exists) stays false.

Offline checks make two causes unlikely, but neither was timed at a real
login: the plugin registry scan (one `find`) and QML compilation (about 1 s
offscreen in total, entry points only). Left are object creation and startup
work of the loaded set (about 30 bar widgets on two monitors, the plugin
services, the `keepLoaded` overlays) and the shell's own non-plugin startup.
The shell log has one-second resolution and no per-plugin timing, so we
cannot tell which of these costs the time.

## Proposed outcome

One login on p620 produces a millisecond timeline covering:

- every bar widget, plugin service and panel or overlay loader: when it
  started, finished and completed (`Component.onCompleted`);
- the registry scan's start and end, each plugin reload, and every change of
  `desktopReady` and the flags it is made of;
- a few core shell milestones (`Configuration Loaded`, bar created per
  monitor, IPC handler ready);
- a cheap main-loop stall marker (a short repeating timer that logs when it
  fires late), so async wall-clock time is not mistaken for cost.

From that we pick what to cut or defer in a follow-up change (that fix is not
part of this task).

## Affected users and systems

- p620 only, for the measurement login. razer gets nothing new.
- The Omarchy shell from nixarchy, patched for p620 only through the
  NixOS option `programs.nixarchy.package` (an `overrideAttrs` with a patch),
  not through the global `./overlays`, which every host imports. No change in
  the nixarchy repo is needed for the measurement itself.
- The startup probe (`~/.local/share/startup-probe`) stays as it is.

## Constraints

- Temporary and easy to remove: the patch is off unless an environment
  variable is set, and the revert is a single commit.
- Logging must not change load order or timing in a way that hides the cost:
  no synchronous file writes per event. Lines go to the shell's own log with
  a `Date.now()` millisecond stamp in the message, since the log's own
  timestamps are whole seconds.
- No change to what plugins load or how they behave.
- p510 is untouched. Deploy p620 only, with the bus announcement first.
- Needs one logout and login by the owner to collect the data.

## Open questions

- Patch the shell for p620 here, or as a gated PR to nixarchy so it is
  available on every host and in a microVM? Recommendation: p620 here first;
  upstream it only if the microVM bisect turns out to be needed.
- Whether a zero-patch check (`QT_MESSAGE_PATTERN` with millisecond time, or
  a QML profiler capture) can replace part of the patch. The spec checks this
  first and keeps the patch to what it cannot show.
- If no single plugin stands out, do the microVM clean-vs-ours bisect next,
  as already agreed in the issue.
