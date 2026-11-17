---
status: draft
issue: 2989
intent: intent/2026-11-17-2989-hc-core-clean-env.md
---

# Spec: the hc core always starts with a clean environment

## Design

A new script `home/development/hc-core-ensure.sh`, packaged in `home/development/herdr.nix` as a
`writeShellApplication` (`hc-core-ensure`) with its test in `checkPhase`, like `herdr-team` in
`home/development/agent-run.nix`. `hc` is called by its store path (`${pkgs.customPkgs.herdr-core}/bin/hc`), never
from PATH.

1. **Run in the user manager's environment.** Unless `HC_CORE_ENSURE_INNER=1` is set, the script re-runs itself
   with `systemd-run --user --collect --wait --quiet -p Type=oneshot --setenv=HC_CORE_ENSURE_INNER=1 -- <itself>`.
   A transient unit gets the manager's environment, not the caller's, so the core it starts is clean whoever called
   the helper. With no user bus it exits 0 and does nothing (SSH without a session).

2. **Decide.**
   - `hc server status --json` fails (no core): `hc server start`. hc starts the core through its own
     `systemd-run`, from this (clean) environment.
   - The core runs: read the names in its saved environment file, `/run/user/<uid>/hc-serve-*/environment` of the
     running `hc-serve-*` unit (`systemctl --user show -p EnvironmentFiles` of the unit whose `MainPID` is the
     status `pid`). It is polluted when it has a name that matches the caller patterns and is **not** in
     `systemctl --user show-environment`:
     `HERDR_*` except `HERDR_APP_HOME`, `TMUX`, `TMUX_PANE`, `CLAUDE_CODE_SESSION_*`, `CLAUDE_CODE_CHILD_SESSION`,
     `CLAUDE_CODE_MESSAGING_*`, `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_EXECPATH`,
     `NIX_CONFIG`, `*API_KEY*`, `*_TOKEN`. Names only: values are never read into variables, printed or logged.
     Comparing with the manager's names keeps `*_API_KEY_FILE` paths and `TMUX_TMPDIR`, which the manager has on
     purpose (checked on p620), from counting.
   - Polluted: `hc server restart --fresh` (programs keep running; terminals opened afterwards get the clean
     environment). Log the offending names (not values) with `systemd-cat -t hc-core-ensure`.
   - Clean: nothing.
   - Every path exits 0: the helper must never block a login or an app launch.

3. **Callers.**
   - `systemd.user.services.hc-core-ensure` (Home Manager): `Type=oneshot`, `ExecStart=hc-core-ensure`,
     `After=graphical-session.target`, `PartOf=graphical-session.target`, `WantedBy=graphical-session.target`, and
     `X-RestartIfChanged=false` so a Home Manager switch never runs it. `PartOf` without `RemainAfterExit` lets it
     run again at the next login.
   - `pkgs/herdr-app/default.nix` `syncOnLaunch`: before `herdr-app-sync`, `hc-core-ensure || :`, with the same
     `$# -eq 0` window-launch test, in the background (`setsid -f`) so a slow restart never delays the window.
     herdr-app takes `hc-core-ensure` as a package argument from `pkgs/default.nix`, like `herdr-app-sync`.

4. **Docs.** `docs/applications/herdr.md`: the "hc keeps its first starter's environment" section and the #2989
   row in Known gaps change to describe the helper and its limits (an hc command before login, or between a core
   exit and the next app launch, can still start a dirty core until the next login or launch). The manual repair
   becomes `hc-core-ensure`.

## Alternatives rejected

- A permanent `hc-core.service` that owns the core process: hc runs the core in its own transient `hc-serve-*`
  unit and has no foreground mode for a supervisor; running it twice would fight over the socket.
- Patching hc to drop caller environments: the intent keeps hc unpatched.
- Filtering every command's environment (wrapping `hc` on PATH): misses herdr-app's own calls and the agents' store
  paths, and hc would still save whatever the first unwrapped caller had.
- `restart --fresh` at every login without checking: needless restarts of a clean core with live agents.

## Risks

- A false "polluted" verdict restarts the core: programs keep running, but each restart is visible as a short
  reconnect in the app. The names-only check against the manager's environment keeps that rare; the log line says
  why.
- `hc server restart --fresh` on a core with live remote (SSH) terminals: hc keeps programs across restarts; not
  tested on remote terminals here.
- Login ordering: if UWSM imports the graphical environment after `graphical-session.target`, the core misses
  `WAYLAND_DISPLAY`. Checked in verification.
- Hosts: p620 and razer, user units only.

## Verification

- `home/development/hc-core-ensure-test.sh` in the package's `checkPhase`, with fake `hc`, `systemd-run`,
  `systemctl` and `systemd-cat` on PATH, and `HC_CORE_ENSURE_INNER=1` to test the inner logic:
  - no core → `server start` once;
  - core with a clean file (only manager names, including `*_API_KEY_FILE` and `TMUX_TMPDIR`) → no call;
  - each of `HERDR_ENV`, `TMUX`, `CLAUDE_CODE_SESSION_ID`, `NIX_CONFIG`, `FOO_API_KEY` in the file and not in the
    manager → `server restart --fresh` once, and the log names the variable but no value;
  - `HERDR_APP_HOME` alone → no call;
  - outer run without `HC_CORE_ENSURE_INNER` → calls `systemd-run … --setenv=HC_CORE_ENSURE_INNER=1`;
  - every case exits 0, including a failing fake `hc`.
- Build p620 and razer.
- On p620 after deploy: start a throwaway core from a polluted environment is not done (live agents run on the
  core). Instead: `hc-core-ensure` on the current clean core does nothing (log), and from a Herdr TUI pane
  (`HERDR_ENV=1`, `TMUX` set) it still sees the core as clean (it runs in the manager's environment, not the
  pane's). `systemctl --user status hc-core-ensure` after the next login: ran once, exit 0; a new app terminal has
  no `HERDR_ENV`, `TMUX` or `NIX_CONFIG`, and has `WAYLAND_DISPLAY`.
