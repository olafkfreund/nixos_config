---
status: draft
issue: 2989
author: olafkfreund
---

# Intent: the hc core always starts with a clean environment

## Problem

herdr-core (`hc`) saves the environment of whichever process first starts the core and reuses it for every terminal
it opens, across `hc server restart` and updates. The core starts on demand: the first `hc` command, `herdr-app`
launch or `herdr-team`/`herdr-run` call starts it if it is not running. When that first caller is a Herdr TUI pane
or a Claude Code session, every app terminal inherits `HERDR_ENV=1`, `TMUX`, the Claude session variables and that
caller's token, and `claude()` and `herdr-team` behave as if they were in the TUI. It happened twice during #2978.

# 2978 and #2987 limit the damage: `hcShell` strips those variables from plain app shells, and the argv guard does
the same for argv launches in interactive bash. They don't cover everything: non-interactive `hc run` commands and
`herdr-team` members still inherit the saved environment, and the repair (`systemd-run --user --collect --wait -p
Type=oneshot hc server restart --fresh`, documented in `docs/applications/herdr.md`) is manual.

## Proposed outcome

On p620 and razer the core is started at graphical login by a systemd user unit, from the user manager's
environment (the same one `uwsm app` launches get), before anything else can start it. After a reboot or relogin,
`/proc/<core pid>/environ` has no `HERDR_*`, `TMUX`, `CLAUDE_CODE_SESSION_*` or similar caller variables, whichever
app or agent touches hc first. A core that was already polluted gets repaired by one documented command, or by the
next login.

## Affected users and systems

- p620 and razer (`programs.herdrSkill.enable`), Home Manager user units in `home/development/herdr.nix`.
- Everything that runs on hc: herdr-app terminals, `herdr-team`/`herdr-run` hc backends, Claude agent teams.
- The Herdr TUI is unaffected (its own server).

## Constraints

- Never stop or restart a running core as a side effect of a Home Manager switch: that would disturb live agents
  (`hc server restart` keeps programs running, but a stop would not).
- Keep `hc` itself unpatched; use its CLI (`hc server start`/`status`/`restart --fresh`).
- The core must not inherit the user manager's own secrets beyond what `uwsm app` launches already get; nothing new
  is added to the environment.
- Stacked on `feat/2978-herdr-app-parity` (#2990), which owns the hc config in `herdr.nix`.
- Bus announcement before deploys; p510 untouched.

## Open questions

- If a core is already running at login (an old one kept alive across a relogin, or started by an early agent),
  should the unit leave it alone, or restart it with `--fresh` when its environment has a TUI or Claude identity?
  Recommendation: restart with `--fresh` only when the saved environment has `HERDR_ENV` or a Claude session
  variable (programs keep running across a restart), otherwise leave it.
