---
status: approved
issue: 2989
spec: spec/2026-11-17-2989-hc-core-clean-env.md
coders:
  1: codex # small, tricky shell: self re-exec through systemd-run, lock, marker hygiene, and its test
  2: coder # Nix wiring in three files
  3: coder # docs
reviewers:
  - codex # independent read of the helper and wiring against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: the hc core always starts with a clean environment

Branch `fix/2989-hc-core-clean-env`, worktree `~/.config/nixos-2989`, stacked on `feat/2978-herdr-app-parity`
(PR #2990). The PR targets that branch until #2990 merges.

## Approved decisions (from the spec)

- New package `hc-core-ensure` in `pkgs/hc-core-ensure/`, registered in `pkgs/default.nix` next to `herdr-app-sync`
  (line 134). Usage `hc-core-ensure login|launch`.
- hc is called as `@hc@`, replaced at build time with `${herdr-core}/bin/hc`; never from PATH.
- Outer run: `systemd-run --user --collect --wait --quiet -p Type=oneshot -p TimeoutStartSec=60
  --setenv=HC_CORE_ENSURE_INNER=1 -- <itself> <mode>`, so the work runs in the user manager's environment. No user
  bus: exit 0, nothing done.
- Inner run: `unset HC_CORE_ENSURE_INNER` first; `flock -w 60` on `$XDG_RUNTIME_DIR/hc-core-ensure.lock`.
  - `login`: `hc server status` ok → `hc server restart --fresh`; else `hc server start`.
  - `launch`: status fails → `hc server start`; else nothing.
- No environment parsing at all. Every path exits 0 and logs one line (`systemd-cat -t hc-core-ensure`, mode and
  action, no environment values).
- Home Manager unit `hc-core-ensure` (gated by `programs.herdrSkill.enable`): `Type=oneshot`,
  `ExecStart=… login`, `After=`, `PartOf=` and `WantedBy=graphical-session.target`, `RefuseManualStart=true`,
  `X-RestartIfChanged=false`. A Home Manager switch must never start it.
- herdr-app wrapper: `hc-core-ensure launch || :` in the foreground, first thing inside the `$# -eq 0` window-launch
  block, before the sync.

## Steps

- **Step 1:** `pkgs/hc-core-ensure/default.nix`, `hc-core-ensure.sh`, `test.sh` (new) and `pkgs/default.nix:134`
  (add `hc-core-ensure = pkgs.callPackage ./hc-core-ensure { inherit (pkgs.customPkgs) herdr-core; };`).
  - `default.nix`: `writeShellApplication` like `pkgs/herdr-app-sync/default.nix`, `runtimeInputs` systemd,
    util-linux (flock), coreutils; `text` is the script with `@hc@` replaced (`lib.replaceStrings`) by
    `${herdr-core}/bin/hc`; a custom `checkPhase` replaces writeShellApplication's default checks, so it runs
    them itself on `$target` (the generated script, with the substituted path and preamble): `runHook preCheck`,
    `${stdenv.shellDryRun} "$target"`, `${lib.getExe shellcheck-minimal} "$target"`, then
    `bash ${./test.sh} ${./hc-core-ensure.sh}`, `runHook postCheck`. The test's own tools come from
    `derivationArgs.nativeBuildInputs = [ python3 util-linux ]` (`runtimeInputs` only reaches the generated
    script's PATH, not the check).
  - The script finds itself through `$0` for the re-exec (writeShellApplication's `$0` is the store path). The
    shorter lock wait in tests comes from `HC_CORE_ENSURE_LOCK_WAIT` (default 60); no other test hooks.
  - `test.sh` builds an executable copy of the script with a shebang from `command -v bash` (the sandbox has no `/usr/bin/env`),
    `set -euo pipefail`, `chmod +x`, and `@hc@` replaced by a fake hc (logs its arguments and whether
    `HC_CORE_ENSURE_INNER` is in its environment; `status` succeeds or fails by a state file), puts fake
    `systemd-run` (logs its arguments, then runs the command after `--` with the `--setenv` value) and
    `systemd-cat` (appends stdin to a log) first on PATH, and sets `XDG_RUNTIME_DIR` to a temp dir with a fake bus
    socket (`python3 -c` binding `AF_UNIX`). Cases, each asserting the hc log exactly:
    outer run calls `systemd-run` with `--setenv=HC_CORE_ENSURE_INNER=1` and the mode, and the outer process
    itself makes no hc call; `login` up → `server restart --fresh`; `login` down → `server start`; `launch` down
    → `server start`; `launch` up → no call; the fake hc never sees `HC_CORE_ENSURE_INNER`; failing hc → exit 0
    and a log line; no bus socket → exit 0, no `systemd-run`; lock held by the test (`flock` in a subshell) with
    `HC_CORE_ENSURE_LOCK_WAIT=1` → exit 0 and a "busy" log line; an unknown mode → exit 0, a log line, no hc call;
    two runs serialize: the first run's fake hc blocks on a fifo, the second run is started and has not reached hc
    (the hc log has one entry), then the first is released and both complete in order.
  Check: `nix build .#nixosConfigurations.p620.config.system.build.toplevel --no-link` succeeds after step 2 wires
  it; for step 1 alone, `nix build --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.p620.pkgs.customPkgs.hc-core-ensure'`
  `--no-link`, or the equivalent attribute; then break one case on purpose (for example drop the `unset`) and see the build
  fail, then restore.
  Traps: `writeShellApplication` runs with `set -euo pipefail`, so every hc and `systemd-run` call is guarded
  (`|| …`); `TimeoutStartSec` bounds the inner run; the fake `systemd-run` must run the command with the
  `--setenv` value in its environment, as the real one does; the Nix build sandbox has no user bus.

- **Step 2:** wiring.
  - `pkgs/default.nix:133`: herdr-app's `inherit` gains `hc-core-ensure`.
  - `pkgs/herdr-app/default.nix`: new argument `hc-core-ensure`; in `syncOnLaunch` (line 36), right after
    `export HERDR_APP_SYNC_RUNNING=1`, `${hc-core-ensure}/bin/hc-core-ensure launch || :`.
  - `home/development/herdr.nix`: the `config` block at line 64 is not gated as a whole, so wrap the new
    entries in `lib.mkIf cfg.enable` like the `home.file` entry at line 65: `systemd.user.services.hc-core-ensure`
    with `Unit = { Description; After = [ "graphical-session.target" ]; PartOf = [ "graphical-session.target" ];
    RefuseManualStart = true; X-RestartIfChanged = false; }`, `Service = { Type = "oneshot"; ExecStart =
    "${pkgs.customPkgs.hc-core-ensure}/bin/hc-core-ensure login"; }`, `Install.WantedBy =
    [ "graphical-session.target" ]`; and `pkgs.customPkgs.hc-core-ensure` in `home.packages` for manual runs.
  Check: `just test-host p620`; the generated unit file in the built home files has `RefuseManualStart=true` and
  `X-RestartIfChanged=false`; the herdr-app wrapper script contains the `hc-core-ensure launch` line before the
  sync.
  Traps: Home Manager `systemd.user.services` attribute names are the unit file keys (`X-RestartIfChanged` is
  fine as a key); keep the existing `syncOnLaunch` behaviour unchanged. AGENTS.md's service hardening rule
  (`DynamicUser`, `ProtectHome` …) is for system services; this is a user oneshot that must run as the user
  against the user's hc state, so it gets none of those (state this in a one-line comment).

- **Step 3:** `docs/applications/herdr.md` (around lines 400-415): the #2989 Known-gaps row and the "hc keeps its
  first starter's environment" section describe the helper (login fresh restart, launch start-only, manager
  environment), the manual repair becomes `hc-core-ensure login` (in a `bash` fence), and the limit (an hc command
  before login, or between a core exit and the next app launch, can start a dirty core until the next login).
  Check: markdownlint (pre-push); no line starts with `#` and a digit; lines ≤ 120.

- **Step 4 (lead):** a local `deploy/` branch from the finished branch, merging `origin/fix/2987-hc-argv-scope`,
  `origin/fix/2988-herdr-team-provider-scan` and `origin/fix/gnome-file-picker`; `just test-host p620` and `razer`
  on it; bus `read_new` + `post`; `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620` and
  `… just deploy-via-p620 razer`. The Home Manager switch log must not show `hc-core-ensure` being started.
  Live on p620, announced on the bus first (it restarts the core):
  - from a Herdr TUI pane: `hc-core-ensure login`; journal shows "login: restart --fresh";
  - then `herdr-app do tab.new --argv '["sleep","300"]'`, take the terminal ID it returns, resolve its PID with
    `hc get`, and read only the variable names in `/proc/<pid>/environ`: no `HERDR_ENV`, `TMUX`,
    `CLAUDE_CODE_SESSION_*`, `NIX_CONFIG`; `WAYLAND_DISPLAY` present; close only that tab;
  - running agents (listed with `hc ls` before) are still live;
  - `herdr-app` launch with the core up logs "launch: core running".
  If the bus shows a conflicting job, wait. The owner checks after their next login:
  `journalctl --user -t hc-core-ensure -b` shows one "login" line for that login.

- **Step 5 (lead):** commit per step, push, PR (links intent, spec, plan; who did which step), workflow or Opus
  review of the diff, `@codex review`.

## Tests

- Step 1's suite runs in the package build on every host.
- `just test-host p620`, `just test-host razer`; step 4's live check.

## Rollback

Revert the PR (steps 1-3) and switch. The unit disappears; the app wrapper stops calling the helper. The core keeps
running with whatever environment it has; `systemd-run --user --collect --wait -p Type=oneshot hc server restart
--fresh` is the manual repair again.
