---
status: draft
issue: 3165
spec: spec/2026-11-22-3165-shell-startup-timing.md
coders:
  2: agy    # about 35 mechanical log-line insertions across four QML files
  1: lead   # copying four files from the store, no code
  3: lead   # cutting the patch is a diff command, plus the compile check
  4: lead   # ten lines of Nix in one file, below the hand-off threshold
reviewers:
  - codex   # read of the patch and the Nix diff against this plan
  - agy     # independent read of the same diff
---

# Plan: per-plugin startup timing for the Omarchy shell (p620 only)

## Approved decisions (from the spec)

- A patch to the Omarchy shell QML adds `console.log("startup-timing", <event>, <id>, [value])`
  lines. Nothing is logged unless the session has `OMARCHY_STARTUP_TIMING=1`.
  Quickshell's `log.log` and the journal (`-o short-precise`) already carry
  millisecond timestamps, so no `Date.now()` stamps.
- Each of the four patched files gets its own gate property,
  `readonly property bool startupTiming: Quickshell.env("OMARCHY_STARTUP_TIMING") === "1"`
  (all four already `import Quickshell`), and every new line is
  `if (startupTiming) console.log("startup-timing", …)` (or `root.`/`shell.`
  qualified where the scope needs it).
- Shipped on p620 only: `hosts/p620/nixos/omarchy-startup-timing.patch`,
  applied in `postInstall` of an `overrideAttrs` on
  `programs.nixarchy.package`, with `patch --forward --fuzz=0` so drift fails
  the build. `environment.sessionVariables.OMARCHY_STARTUP_TIMING = "1"` in the
  same file. `./overlays` and shared modules are not touched; razer and p510
  get nothing.
- The patch is cut against the tree main builds today:
  `/nix/store/lm3mmcv2b0qi2lpl6rb4hnczn47hdmh1-omarchy-edge-20261122-48138d9/share/omarchy`
  (call it `$S`). Patch paths are `a/shell/...` / `b/shell/...` so `-p1`
  applies from `$out/share/omarchy`.
- Reading the result is one `grep startup-timing` over `log.log`, posted to
  issue 3165 as a table. No report script.
- Done when the timeline is posted. The fix it points to is a new task.

## Hook points in `$S/shell` (line numbers as of 48138d9)

`shell.qml` (root id `shell`):

| # | Where | Line(s) | Log |
|---|---|---|---|
| 0 | root properties, next to `property bool pluginReloading` | 67 | add the `startupTiming` gate property |
| 1 | root `Component.onCompleted`, first statement | 178 | `shell-completed` |
| 3 | new root handlers `onPluginReloadingChanged` and `onBarChanged` (none exist today) | near 67 / 223 | `reloading <bool>`, `bar-set <bar ? "yes" : "null">` |
| 4 | `ensureService`: before `Qt.createComponent` | 966 | `service-begin <key>` |
| 4 | `finalize`: first statement | 968 | `service-compiled <key> <comp.status>` |
| 4 | `finalize`: after `createObject` and its null check | 975-979 | `service-created <key>` |
| 4 | `finalize`: last statement (after the `_services = snext` / `AuthServiceStore.put` branch) | 995 | `service-wired <key>` |
| 5 | `loadPluginWidget`: before `Qt.createComponent` | 1648 | `widget-begin <registryKey>` |
| 5 | `finalize`, Ready branch: before / after `barWidgetRegistry.register` | 1651 | `widget-compiled <registryKey>`, `widget-registered <registryKey>` |
| 8 | panel delegate `QtObject panelEntry`: new `Component.onCompleted` | 1431-1440 | `panel-entry-created <pluginId> <keepLoaded>` |
| 8 | `panelLoader`: new `Component.onCompleted` and `onActiveChanged` | 1440-1443 | `panel-loader <pluginId> <active>`, `panel-active <pluginId> <active>` |
| 8 | `panelLoader.onLoaded`: first statement | 1444 | `panel-loaded <pluginId>` |
| 9 | `SocketServer` (line 1745): new `Component.onCompleted` and `onActiveChanged` | 1745-1747 | `ipc-ready <active>` |
| 11 | new root `Timer` (stall marker) | end of root | see below |

Stall marker (11): a root-level

```qml
Timer {
  property double last: 0
  interval: 50; repeat: true
  running: shell.startupTiming && !stopped
  property bool stopped: false
  onTriggered: {
    var now = Date.now()
    if (last && now - last > 150) console.log("startup-timing", "stall", now - last)
    last = now
  }
}
Timer { interval: 20000; running: shell.startupTiming; onTriggered: <stall timer id>.stopped = true }
```

Give the first timer an id (`startupStallTimer`). `Date.now()` here only
measures the gap; the log line's own timestamp places it.

`services/PluginRegistry.qml` (root id `registry`):

| # | Where | Line | Log |
|---|---|---|---|
| 0 | next to `property bool scanning` | 26 | gate property |
| 2 | `rescan()`, after `scanning = true` | 754 | `scan-start` |
| 2 | scan end, right before `scanning = false` | 672 | `scan-end <Object.keys(merged).length>` |

`plugins/bar/Bar.qml` (root id `root`):

| # | Where | Line | Log |
|---|---|---|---|
| 0 | a root property | top of root | gate property |
| 6 | `WidgetHost` `componentLoader`, `registryLoader`, `qmlLoader`: new `onActiveChanged: if (active && root.startupTiming) …` | 2710, 2723, 2736 | `widget-instance-begin <host.key> <component\|registry\|qml>` |
| 6 | same three loaders, first statement of `onLoaded` | 2716, 2729, 2742 | `widget-instance-done <host.key> <component\|registry\|qml>` |
| 7 | `BarPanel` `Component.onCompleted` (line 1722), turned into a block that keeps the existing statement | 1722 | `bar-completed <screen.name>` |

For synchronous loaders, `onActiveChanged` may fire after the load, so
begin/done can read 0 ms apart; the stall marker then carries the cost. A key
logged twice is one widget per screen (expected on two monitors).

`services/BackgroundIntro.qml` (root id `root`):

| # | Where | Line | Log |
|---|---|---|---|
| 0 | next to `property bool startupMediaReady` | 19 | gate property |
| 10 | `onDesktopReadyChanged: revealStartup()` becomes a block: log, then `revealStartup()`. Never a second handler (compile error) | 69 | `desktop-ready <desktopReady> reloading=<host.pluginReloading> scanning=<host.pluginRegistry && host.pluginRegistry.scanning> bar=<!!host.bar>` (guard `host` null) |
| 10 | new `onStartupMediaReadyChanged` | near 19 | `media-ready <startupMediaReady>` |
| 10 | `revealStartup()`, right before `startupFade.start()` | 66 | `fade-start normal` |
| 10 | 10 s fallback `Timer.onTriggered`, before `startupFade.start()` | 181 | `fade-start timeout` |
| 10 | cover `FrameAnimation.onTriggered`, inside `if (readyFrames === 2)` | 320 | `cover-frames-ready <modelData.name>` |

The last row is an addition to the spec's list: `revealStartup()` also waits
for every per-screen cover to have drawn two frames (`readyFrames < 2`, line
65), which the spec did not name. Without it a late fade after
`desktop-ready true` would be unexplained.

## Steps

1. **Lead: set up the work copy.**
   `mkdir -p work/3165/{a,b}/shell/{services,plugins/bar}`; copy the four
   files from `$S/shell` into both `a/` and `b/` at the same relative paths;
   `chmod -R u+w work/3165`. `work/` is never staged; it is deleted in step 3.
   → verify: `diff -r work/3165/a work/3165/b` prints nothing.
   Traps: worktree only, never `~/.config/nixos`.

2. **agy (`agy-implement`, through `herdr-team`): add the log lines** in
   `work/3165/b/shell/` exactly as the four tables above say: gate property
   first, then each hook, nothing else changed (no reformatting, no reordering,
   no new imports). Prompt names this plan path and step 2.
   → verify (lead, `--verify`): `diff -u -r work/3165/a work/3165/b | grep -c '^+.*startup-timing'`
   is at least 30, `grep -c '^-'` shows only the edited single lines
   (`onDesktopReadyChanged`, `BarPanel` `Component.onCompleted`, and any line
   turned into a block), and the compile check in step 3 passes.
   Traps: a QML syntax error takes the whole shell down; agy does not stage,
   commit, deploy or restart.

3. **Lead: compile check and cut the patch.**
   - Compile check: a throwaway offscreen harness (as used in #3147's
     timing work) with `QT_QPA_PLATFORM=offscreen`, `HOME` and
     `XDG_RUNTIME_DIR` set to a temp dir and `DBUS_SESSION_BUS_ADDRESS`
     unset, that `Qt.createComponent`s each patched file from a copy of the
     full `$S/shell` tree with the four files swapped in, and prints
     `errorString()`. Expect no errors (missing-runtime warnings are fine).
   - `(cd work/3165 && diff -ru a b) > hosts/p620/nixos/omarchy-startup-timing.patch`
     (exit 1 from diff is normal).
   - `cp -r $S /tmp-scratch/omarchy && chmod -R u+w` it, then
     `patch -d <copy> -p1 --forward --fuzz=0 --dry-run < hosts/p620/nixos/omarchy-startup-timing.patch`
     → applies cleanly.
   - `rm -rf work/`.
   Traps: write the patch with a file, not a heredoc through `git commit -m`.

4. **Lead: `hosts/p620/nixos/nixarchy.nix`.** After the `imports` list, add:

   ```nix
   # Temporary startup timing for #3165; remove with the patch file.
   programs.nixarchy.package =
     (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (o: {
       postInstall = (o.postInstall or "") + ''
         patch -d $out/share/omarchy -p1 --forward --fuzz=0 \
           < ${./omarchy-startup-timing.patch}
       '';
     });
   environment.sessionVariables.OMARCHY_STARTUP_TIMING = "1";
   ```

   (`inputs` and `pkgs` are already arguments of the file.)
   → verify: `nix eval --raw .#nixosConfigurations.p620.config.programs.nixarchy.package.name`
   still reads `omarchy-edge-20261122-48138d9`, and
   `nix eval --raw .#nixosConfigurations.p620.config.programs.nixarchy.tree`
   differs from `/nix/store/8fa4vnbfpf4v82ipq5cjy3dbb36dc7jj-nixarchy-omarchy-tree`.
   Traps: no global overlay; nothing else in the repo sets this option.

5. **Lead: builds and the gate check.**
   - `just test-host p620` → builds.
   - `nix eval --raw .#nixosConfigurations.razer.config.system.build.toplevel.outPath`
     equals the same eval on `origin/main` → razer unchanged.
   - `grep -c startup-timing <built tree>/shell/shell.qml` is non-zero.
   - Gate check, isolated (temp `HOME` and `XDG_RUNTIME_DIR`, no
     `WAYLAND_DISPLAY`, no `DBUS_SESSION_BUS_ADDRESS`, so it cannot reach the
     live shell's socket, polkit or the compositor):
     `QT_QPA_PLATFORM=offscreen timeout 20 qs -p <built tree>/shell`, once
     without and once with `OMARCHY_STARTUP_TIMING=1`; grep its log.
     Expect no `startup-timing` line without, and `shell-completed` with.
     If the isolated shell will not start at all, report that and rely on the
     compile check plus the built-file grep; do not run it against the live
     session.
   Traps: p510 is not built.

6. **Lead: commit, PR, review, merge, deploy p620.**
   - Commit (`perf(omarchy): startup timing log for p620 (#3165)`) with the
     patch and `nixarchy.nix`, plus this plan if anything deviated. Push,
     check the remote head.
   - PR linking intent, spec and plan; say agy did step 2 (or that the lead
     did, if the handoff failed). `gh pr comment <n> --body '@codex review'`.
   - Read-only reviews by Codex and agy (second-opinion), in parallel, with
     `git status --porcelain` before and after. Address real findings.
   - Merge. Check no `nhs` is running, pull `~/.config/nixos` on main,
     read the bus, post the p620 deploy (about 5 min), then
     `AGENT_BUS_ANNOUNCED=1 just p620`. Expect no failed units.
   Traps: the running shell keeps the old tree until the next login; that is
   expected. Do not restart the shell for the owner.

7. **Owner: log out and back in on p620.** Then the lead reads
   `$XDG_RUNTIME_DIR/quickshell/by-pid/<new pid>/log.log`:
   `grep startup-timing`, turns it into a table (time, event, id, gap), and
   posts it on issue 3165 with the top costs, the stalls, the double-creation
   verdict for the five panels, and which of the reveal inputs was last.
   → done.

## Tests

| Check | Expected |
|---|---|
| compile harness on the four patched files | no QML errors |
| `patch --dry-run --forward --fuzz=0` on a copy of `$S` | applies |
| `just test-host p620` | builds |
| razer toplevel vs `origin/main` | identical |
| isolated offscreen gate check | silent without the variable, `shell-completed` with it |
| after login | `shell-completed`, `scan-start`/`scan-end`, `service-*` per service, panel and widget lines, `desktop-ready true`, `fade-start` |

## Rollback

- Turn the logs off without a rebuild of the shell: drop the
  `sessionVariables` line and redeploy (takes effect at the next login).
- Remove everything: revert the step 6 commit (patch file and the
  `nixarchy.nix` lines) and deploy p620. That revert is also the cleanup once
  the timeline is posted, and must land before the next nixarchy edge bump,
  which would otherwise fail the p620 build on the patch.
- A shell that will not start after login: boot or switch to the previous
  generation.
