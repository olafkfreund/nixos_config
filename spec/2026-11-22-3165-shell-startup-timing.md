---
status: approved
issue: 3165
intent: intent/2026-11-22-3165-shell-startup-timing.md
---

# Spec: per-plugin startup timing for the Omarchy shell

## What the existing log already shows

The no-patch check the intent asked for comes first, and it partly
succeeds. Quickshell writes `$XDG_RUNTIME_DIR/quickshell/by-pid/<pid>/log.log`
with millisecond timestamps, and the journal has them too with
`journalctl --user -o short-precise`. The "one-second resolution" in the issue
was the default `qs log` view, not the data. So the patch does not need
`Date.now()` stamps: plain `console.log` lines are timed already.

The 2026-11-21 08:47 login, read from `log.log` (seconds past 08:47):

| Time | Event |
| --- | --- |
| 49.58 | quickshell launches the config |
| 50.56 | log file opened (1 s of quickshell's own start) |
| 50.96 | `Configuration Loaded` |
| 51.10 → 52.75 | nothing logged for 1.65 s |
| 52.75 | `idle` service ready |
| 53.52 → 54.54 | plugins load one after another: omarecorder, webcam, omarchroma, gliff-manager, pixelbuds, rebuild, omadroid, promaa.clock (one warning each, 40-340 ms apart) |
| 54.75 | polkit agent registered |
| 55.08 | owed's IPC answered, loop free |
| about 58.0 | cover lifts (`desktopReady`) |

Two leads come out of it:

- Eight plugins log `Handler was registered but will not be used because
  another handler is registered`. For the three bar widgets (webcam,
  omarchroma, promaa.clock) that is expected: `Bar.qml` builds every widget
  once per screen and p620 has two. The five panels (omarecorder,
  gliff-manager, pixelbuds, rebuild, omadroid) are not per screen, so either a
  panel is created twice at startup (the `syncPanelEntries` rebuilds the
  comment near `syncPanelEntries` in `shell.qml` describes) or the panel and
  its bar widget claim the same IPC target. Hook 8 below settles which.
- Neither the 1.65 s silence nor the 2.9 s after 55.08 is explained by what
  is logged today. That is what the patch is for.

A QML profiler capture is rejected below; `QT_MESSAGE_PATTERN` is not needed
since the times are already there.

## Design

A patch to the Omarchy shell QML that adds `console.log("startup-timing", …)`
lines, off unless `Quickshell.env("OMARCHY_STARTUP_TIMING") === "1"`, plus a
p620-only way to ship it.

### Where the lines go

All in the package's `share/omarchy/shell`. Hook points are named by function
or object, not line number: main now carries `omarchy-edge-20261122-48138d9`
(#3176), newer than the 20261117 build the 08:47 login ran, and the plan
records the exact lines in that version. Each line is
`startup-timing <event> <id> [value]`, so `grep startup-timing log.log` gives
the timeline.

1. `shell.qml` root `Component.onCompleted`: `shell-completed`.
2. `PluginRegistry.qml`: `scan-start` in `rescan()` after its
   `if (scanning) return` guard (it is called from two places), and
   `scan-end <count>` where `scanning = false`.
3. `shell.qml`: `reloading <bool>` on `onPluginReloadingChanged` and
   `bar-set <id>` on `onBarChanged`.
4. `shell.qml` `ensureService`: `service-begin <key>` before
   `Qt.createComponent`, `service-compiled <key>` at the top of `finalize`,
   `service-created <key>` right after `createObject`, and `service-wired <key>`
   at the end of `finalize`, after the property injection and the `_services`
   reassignment, whose bindings can cost time of their own. Services compile
   with `PreferSynchronous`, so begin to compiled is main-thread time.
5. `shell.qml` `loadPluginWidget`: `widget-begin <key>`, and in `finalize`
   `widget-compiled <key>` before and `widget-registered <key>` after
   `barWidgetRegistry.register(…)`.
6. `plugins/bar/Bar.qml` `WidgetHost`: `widget-instance-begin <id> <screen>`
   when its registry or component loader goes active and
   `widget-instance-done <id> <screen>` in its `onLoaded`. These loaders are
   synchronous and run once per screen, so this is where the about 30 widgets
   on two monitors actually cost main-thread time.
7. `plugins/bar/Bar.qml` `BarPanel` `Component.onCompleted` (the existing
   handler, extended): `bar-completed <screen>`.
8. `shell.qml` panel delegate: `panel-entry-created <id> <keepLoaded>` in the
   delegate's `Component.onCompleted`, `panel-loader <id> <active>` in the
   loader's `Component.onCompleted` (a `keepLoaded` panel starts active, so
   `onActiveChanged` never fires for it), `panel-active <id> <active>` on later
   changes, and `panel-loaded <id>` in `onLoaded`. A second
   `panel-entry-created` for one id proves a double creation.
9. `shell.qml` IPC: `ipc-ready` when the shell's IPC socket server is
   listening (its `Component.onCompleted`, or its listening property if it has
   one).
10. `services/BackgroundIntro.qml`: extend the existing
    `onDesktopReadyChanged: revealStartup()` handler (a second handler is a
    compile error) with `desktop-ready <bool>` and the three inputs (reloading,
    scanning, bar present); `media-ready <bool>` on
    `onStartupMediaReadyChanged`; `fade-start normal` at the reveal call and
    `fade-start timeout` at the 10 s fallback.
11. A stall marker in `shell.qml`: a `Timer` (interval 50 ms, `repeat: true`,
    `running` while the gate is on and for the first 20 s) that logs
    `stall <ms>` when more than 150 ms passed since its last tick. That tells
    main-thread blocking apart from asynchronous wall-clock time.

### How it ships, p620 only

- The patch file lives at `hosts/p620/nixos/omarchy-startup-timing.patch`,
  made against the installed tree of the package main builds today
  (`omarchy-edge-20261122-48138d9`).
- `hosts/p620/nixos/nixarchy.nix` sets:

  ```nix
  programs.nixarchy.package =
    (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (o: {
      postInstall = (o.postInstall or "") + ''
        patch -d $out/share/omarchy -p1 --forward --fuzz=0 \
          < ${./omarchy-startup-timing.patch}
      '';
    });
  ```

  The package's `installPhase` ends with `runHook postInstall` (nixarchy
  `pkgs/omarchy/default.nix:2245`), and patching the installed tree means the
  patch is cut against exactly what runs, after nixarchy's own edits.
  The tree nixarchy's apps module builds (`modules/apps.nix`, `omarchyTree`)
  mirrors `${cfg.package}/share/omarchy`, and the HM module reads
  `osConfig.programs.nixarchy.tree`, so both follow. No file in this repo sets
  `programs.nixarchy.package` today, so there is no option conflict.
  `--forward --fuzz=0` matches nixarchy's own `patch` calls: a drifted patch
  fails the build instead of applying in the wrong place.
- `environment.sessionVariables.OMARCHY_STARTUP_TIMING = "1"` on p620, in
  the same file. Dropping the variable turns the logs off without a rebuild
  of the shell; dropping the commit removes everything.
- razer and p510 get nothing: `./overlays` and the shared modules are not
  touched.

### Reading the result

A small script, `scripts/startup-timing-report.sh`, is not added; the plan
uses one `grep startup-timing` plus `awk` over `log.log`, posted to the issue
as a table. Ponytail: a one-off read does not need a tool.

## Alternatives rejected

- A global overlay in `./overlays`: every host imports it, so razer and p510
  would rebuild and carry the patch.
- A gated PR to nixarchy now: an edge publish takes 1.3-2 h and the patch is
  throwaway. It moves upstream only if the microVM bisect needs it.
- QML profiler (`-qmljsdebugger` plus `qmlprofiler`): needs a debug-enabled
  start of the shell under the session's systemd unit and a client attached at
  login, which is fragile for a single run. The log lines plus the stall
  marker answer the question that matters (which plugin, which phase).
- `Date.now()` stamps in each message: not needed, `log.log` has them.
- A file flag instead of an environment variable: the session environment is
  the documented switch. `environment.sessionVariables` reaches the shell
  through `/etc/set-environment`: the running shell already carries
  `NIXOS_OZONE_WL` and `__NIXOS_SET_ENVIRONMENT_DONE`, and p620 already
  passes `NIXPKGS_QT6_QML_IMPORT_PATH` to quickshell the same way.

## Risks

- **The patch no longer applies** after a nixarchy edge bump: the build fails
  on p620 with a clear `patch` error, nothing breaks at runtime. The patch is
  removed as soon as the measurement is taken, before the next bump if
  possible.
- **A logging typo breaks the shell** (a QML syntax error takes the whole
  shell down, see the memory on quickshell imports). Mitigation: the plan
  runs the shell's own offscreen QML load check on the patched tree before
  deploying, and the rollback is one generation back.
- **The log lines change timing**: about 100 lines in 10 s, each a
  `console.log` to a buffered log; negligible against 4 s. The stall timer
  wakes 20 times a second for 20 s, also negligible.
- **Rebuild size:** the omarchy package and the tree are rebuilt on p620; it
  is a `stdenvNoCC` copy and edit, a minute or two.

## Verification

1. `just test-host p620` builds; `just test-host razer` shows the same
   toplevel as main (unchanged).
2. Offscreen QML load of the patched `shell.qml`, `PluginRegistry.qml`,
   `Bar.qml` and `BackgroundIntro.qml` reports no errors.
3. The gate: the offscreen load of the patched `shell.qml` without
   `OMARCHY_STARTUP_TIMING` logs no `startup-timing` line, and with it set to
   `1` logs `shell-completed`. (The shell running at deploy time still runs
   the old store path, so its log proves nothing.)
4. After the owner's logout and login: the grep shows `shell-completed`,
   `scan-start`/`scan-end`, one `service-*` triple per service, the panel and
   widget lines, `desktop-ready true` and `fade-start`. The timeline is
   posted on issue 3165 with the top costs and the double-creation verdict.
5. Done when the timeline is posted; the fix it points to is a new task.
