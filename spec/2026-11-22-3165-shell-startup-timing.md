---
status: draft
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

- Five of those plugins log `Handler was registered but will not be used
  because another handler is registered`, so their `IpcHandler` is created
  twice. Either a panel is instantiated twice at startup (the
  `syncPanelEntries` rebuilds that `shell.qml:1351` mentions) or the panel and
  the bar widget claim the same target. Either way it is work done twice.
- Neither the 1.65 s silence nor the 2.9 s after 55.08 is explained by what
  is logged today. That is what the patch is for.

A QML profiler capture is rejected below; `QT_MESSAGE_PATTERN` is not needed
since the times are already there.

## Design

A patch to the Omarchy shell QML that adds `console.log("startup-timing", …)`
lines, off unless `Quickshell.env("OMARCHY_STARTUP_TIMING") === "1"`, plus a
p620-only way to ship it.

### Where the lines go

All in the package's `share/omarchy/shell` (paths below are relative to it).
Each line is `startup-timing <event> <id>`, so `grep startup-timing log.log`
gives the timeline.

1. `shell.qml` `Component.onCompleted` (line 178): `shell-completed`.
2. `PluginRegistry.qml`: `scan-start` in `rescan()` (line 752) and
   `scan-end` where `scanning = false` (line 672), with the plugin count.
3. `shell.qml`: `onPluginReloadingChanged` and `onBarChanged`
   (`bar-set <id>`).
4. `shell.qml` `ensureService` (line 953): `service-begin <key>` before
   `Qt.createComponent`, `service-compiled <key>` at the top of `finalize`,
   `service-created <key>` after `createObject`. Services are compiled with
   `PreferSynchronous`, so begin→compiled is main-thread time.
5. `shell.qml` `loadPluginWidget` (line 1636): `widget-begin <key>` and
   `widget-ready <key>` in `finalize`.
6. `shell.qml` panel loader delegate (line 1436): `panel-active <id>` on
   `onActiveChanged`, `panel-loaded <id>` in `onLoaded`, and
   `panel-entry-created <id>` in the delegate's `Component.onCompleted`. A
   second `panel-entry-created` for the same id proves the double creation.
7. `plugins/bar/Bar.qml`: `bar-completed <screen>` per bar window.
8. `services/BackgroundIntro.qml`: `desktop-ready <bool>` on
   `onDesktopReadyChanged`, `media-ready <bool>` on
   `onStartupMediaReadyChanged`, and `fade-start` where `startupFade.start()`
   runs (lines 66 and 181).
9. A stall marker in `shell.qml`: a `Timer` (interval 50 ms, repeat, active
   while gated and for the first 20 s) that logs `stall <ms>` when more than
   150 ms passed since its last tick. That tells main-thread blocking apart
   from asynchronous wall-clock time.

### How it ships, p620 only

- The patch file lives at `hosts/p620/nixos/omarchy-startup-timing.patch`,
  made against the installed tree of the current nixarchy edge
  (`omarchy-edge-20261117-9f68da8`).
- `hosts/p620/nixos/nixarchy.nix` sets:

  ```nix
  programs.nixarchy.package =
    (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (o: {
      postInstall = (o.postInstall or "")
        + "patch -d $out/share/omarchy -p1 < ${./omarchy-startup-timing.patch}";
    });
  ```

  The package's `installPhase` ends with `runHook postInstall` (nixarchy
  `pkgs/omarchy/default.nix:2245`), and patching the installed tree means the
  patch is cut against exactly what runs, after nixarchy's own edits.
  `programs.nixarchy.tree` defaults to the package's tree, and the HM module
  reads `osConfig.programs.nixarchy.tree`, so both follow.
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
  the documented switch, and `environment.sessionVariables` reaches the
  Hyprland session through PAM.

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
3. After deploy, `grep startup-timing log.log` is empty in the running shell
   (variable not yet in this session), proving the gate.
4. After the owner's logout and login: the grep shows `shell-completed`,
   `scan-start`/`scan-end`, one `service-*` triple per service, the panel and
   widget lines, `desktop-ready true` and `fade-start`. The timeline is
   posted on issue 3165 with the top costs and the double-creation verdict.
5. Done when the timeline is posted; the fix it points to is a new task.
