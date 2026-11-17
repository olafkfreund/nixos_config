---
status: draft
issue: 2989
intent: intent/2026-11-17-2989-hc-core-clean-env.md
---

# Spec: the hc core always starts with a clean environment

## Design

A package `pkgs/hc-core-ensure/` (`default.nix`, `hc-core-ensure.sh`, `test.sh`) in `pkgs/default.nix`, like
`herdr-app-sync`, so both Home Manager and `pkgs/herdr-app` can use it. `writeShellApplication` with `bash -n`,
ShellCheck and the test in `checkPhase`. The script calls hc as `@hc@`, substituted at build time with
`${herdr-core}/bin/hc` (never PATH, which can hold an older hc); the test substitutes a fake instead.

Usage: `hc-core-ensure login` or `hc-core-ensure launch`.

1. **Manager environment.** Unless `HC_CORE_ENSURE_INNER=1` is set, the script re-runs itself with
   `systemd-run --user --collect --wait --quiet -p Type=oneshot -p TimeoutStartSec=60
   --setenv=HC_CORE_ENSURE_INNER=1 -- <itself> <mode>`. The transient unit has the user manager's environment, not
   the caller's. The inner run unsets `HC_CORE_ENSURE_INNER` first, before any hc call, so the marker never reaches
   the core or its terminals. No user bus: exit 0, do nothing.

2. **One at a time.** The inner run takes `flock -w 60` on `$XDG_RUNTIME_DIR/hc-core-ensure.lock`, so a login run, an
   app launch and a manual run don't race to start or restart the core.

3. **Modes.** No environment parsing: hc's saved environment file is not what new terminals get after a plain
   restart (hc restores its restart state inside the process), so the helper doesn't try to judge pollution.
   - `login`: core running → `hc server restart --fresh` (programs keep running; terminals opened afterwards get the
     manager's environment); no core → `hc server start`. Once per login, which repairs a core that survived
     logout (lingering) or was started dirty since.
   - `launch`: no core → `hc server start`; core running → nothing. Runs in the foreground before herdr-app starts,
     bounded by the 60 s unit timeout, so the app never starts a core from its own environment and never races
     the helper.
   - Every path exits 0 and logs one line (`systemd-cat -t hc-core-ensure`: mode and action, no environment).

4. **Callers.**
   - `systemd.user.services.hc-core-ensure` (Home Manager, `home/development/herdr.nix`, gated by
     `programs.herdrSkill.enable`): `Type=oneshot`, `ExecStart=hc-core-ensure login`,
     `After=graphical-session.target`, `PartOf=graphical-session.target`, `WantedBy=graphical-session.target`,
     `RefuseManualStart=true` and `X-RestartIfChanged=false`. `RefuseManualStart` makes sd-switch treat it as
     stop-only, so a Home Manager switch (first install or later) never starts it; the target's dependency at login
     still does. UWSM 0.27.2 imports the graphical environment before `graphical-session.target`
     (`wayland-session-waitenv.service`), so the core gets `WAYLAND_DISPLAY`. Manual runs use the binary
     (`hc-core-ensure login`), not `systemctl start`.
   - `pkgs/herdr-app/default.nix` `syncOnLaunch`: `hc-core-ensure launch || :` before the existing sync, same
     `$# -eq 0` window-launch test, in the foreground.

5. **Docs.** `docs/applications/herdr.md`: the "hc keeps its first starter's environment" section and the #2989
   Known-gaps row describe the helper; the manual repair becomes `hc-core-ensure login`; the limit: an hc command
   before login, or between a core exit and the next app launch, can start a dirty core until the next login.

## Alternatives rejected

- A permanent `hc-core.service` that owns the core process: hc runs the core in its own transient `hc-serve-*`
  unit and has no foreground mode for a supervisor; running it twice would fight over the socket.
- Patching hc to drop caller environments: the intent keeps hc unpatched.
- Filtering every command's environment (wrapping `hc` on PATH): misses herdr-app's own calls and the agents' store
  paths, and hc would still save whatever the first unwrapped caller had.
- Restart only when the saved environment looks polluted (the first draft): the environment file reflects the
  last launcher, not what the core gives new terminals after a plain restart, and parsing it safely (quoted
  multi-line values) is fiddly. One `restart --fresh` per login is cheap: programs keep running.

## Risks

- A login restart while agents run: hc keeps programs across `restart --fresh`; the app reconnects. Remote (SSH)
  terminals across a restart are not tested here.
- An in-flight hc request at the moment of the login restart can fail once; callers (herdr-team, the app) retry or
  report it.
- Programs started before the repair keep their environment; only new ones are clean.
- Hosts: p620 and razer, user units and the herdr-app wrapper.

## Verification

- `pkgs/hc-core-ensure/test.sh` in `checkPhase`, with the script's `@hc@` replaced by a fake that logs its
  arguments and environment names, and fake `systemd-run`, `flock` stand-ins via PATH:
  - outer run → `systemd-run` with `--setenv=HC_CORE_ENSURE_INNER=1` and the mode; no hc call from the outer run;
  - inner `login`: core up → `server restart --fresh` once; core down → `server start` once;
  - inner `launch`: core down → `server start` once; core up → no call;
  - the fake hc never sees `HC_CORE_ENSURE_INNER`;
  - a failing fake hc, no user bus, and a held lock (timeout shortened by a test variable): exit 0 with a log line;
  - two runs at once: the second waits for the first (the lock).
- Build p620 and razer; the generated unit has `RefuseManualStart=true`, and the Home Manager switch log shows it
  is not started.
- On p620 after deploy: `herdr-app` launch with the core running → log line "launch: core running". From a Herdr
  TUI pane (`HERDR_ENV=1`, `TMUX` set) run `hc-core-ensure login` (announced on the bus: it restarts the core):
  afterwards a new app terminal has no `HERDR_ENV`, `TMUX`, `CLAUDE_CODE_SESSION_*` or `NIX_CONFIG`, has
  `WAYLAND_DISPLAY`, and running agents are still alive. After the owner's next login: the unit ran once, exit 0.
