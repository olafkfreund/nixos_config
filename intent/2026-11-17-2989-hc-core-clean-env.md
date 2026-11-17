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

The fixes from #2978 and #2987 limit the damage, but only for identities: `hcShell` drops selected `HERDR_*`,
Claude session and `TMUX` variables from plain app shells, and the argv guard does the same for argv launches in
interactive bash. Neither filters credentials (`NIX_CONFIG` with the GitHub token, API keys) or anything else the
first caller had, and neither covers direct `hc run` executables or non-interactive scripts. `herdr-team` agents
themselves are safe (`agent-env` runs them under `env -i` with an allowlist), but their launch shells are not. A
restart keeps the saved environment; the repair (`… hc server restart --fresh` through `systemd-run`) is manual
and only affects programs started afterwards.

hc 0.1.21 starts the core itself through `systemd-run` as a transient `hc-serve-*` service, passing the caller's
environment through a private `EnvironmentFile` (`/run/user/<uid>/hc-serve-*/environment`). The core is not tied
to the graphical session (lingering is on), so it survives logout, and a later `hc server start` just connects to
it.

## Proposed outcome

One small helper, `hc-core-ensure`, makes sure a running core started from a clean environment:

- It starts or repairs the core from the **user manager's environment** (through `systemd-run --user`), never from
  its own caller's, so it is safe to call from a TUI pane or an agent.
- If the core is not running, it starts it. If it is running and its saved environment file names a caller
  identity or credential (`HERDR_*` other than `HERDR_APP_HOME`, `TMUX*`, `CLAUDE_CODE_*` session variables,
  `NIX_CONFIG`, `*_API_KEY*`), it runs `hc server restart --fresh` (programs keep running; new terminals get the
  clean environment). Otherwise it does nothing.
- It runs at graphical login (a user unit after `graphical-session.target`, so UWSM's environment is in) and every
  time herdr-app starts (its wrapper already runs `herdr-app-sync`), which covers a core that exited or was started
  early by something else.

Observable: after login, or after launching herdr-app, a new app terminal and a new `hc run` command have none of
those variables, whoever touched hc first. Checked through a newly launched terminal's environment, not only the
core's `/proc/<pid>/environ` (hc changes its own environment after restoring restart state).

Not promised: an hc command run before login, or between a core exit and the next herdr-app launch, can still
start a core from its own environment; the next login or app launch repairs it. Programs already running keep the
environment they started with.

## Affected users and systems

- p620 and razer (`programs.herdrSkill.enable`), Home Manager user units in `home/development/herdr.nix`.
- Everything that runs on hc: herdr-app terminals, `herdr-team`/`herdr-run` hc backends, Claude agent teams.
- The Herdr TUI is unaffected (its own server).

## Constraints

- A Home Manager switch never runs the helper (the unit is not restarted on switch); only login and herdr-app
  launches do. The helper never stops the core; `restart --fresh` keeps programs running.
- Keep `hc` itself unpatched; use its CLI and the declared package path (a login shell can still resolve an older
  `hc` on PATH: 0.1.20 was seen while 0.1.21 runs).
- The core must not inherit the user manager's own secrets beyond what `uwsm app` launches already get; nothing new
  is added to the environment.
- Stacked on `feat/2978-herdr-app-parity` (#2990), which owns the hc config in `herdr.nix`.
- Bus announcement before deploys; p510 untouched.

## Open questions

- The repair list (which saved variables mean "polluted"). Recommendation: the identities above plus `NIX_CONFIG`
  and `*_API_KEY*`; anything the user manager itself has is fine by definition.
