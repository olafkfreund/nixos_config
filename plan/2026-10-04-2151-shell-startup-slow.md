---
status: approved
issue: 2151
spec: spec/2026-10-04-2151-shell-startup-slow.md
---

# Plan: Omarchy shell responsive within seconds of login

## Decisions (from the approved spec)

1. **quickshell:** patch `DesktopEntryMonitor` in the existing
   `overlays/upstream-fixes.nix` override. Parent watches stay, but a parent
   change only rescans when an applications directory's
   `canonicalFilePath()` changed (a generation switch). A change inside an
   applications directory rescans as before. File the bug upstream.
2. **Omamail:** a HM user oneshot sets `windowOpen = false` in
   `~/.config/omamail/window.json` before `graphical-session.target`. The
   plugin itself is untouched. File an upstream request for a setting.
3. **Remove:** gmessages from the Nix config (both hosts' imports, its
   fragment, its package). oma-swiss, omaproton-vpn and spokenshelf as user
   state (directories and `shell.json` references), along with the leftover
   `.bak` directories. omarchy.menu stays disabled (built-in).
4. **nixarchy.microvm:** early return in `focusForMode()` when `Model` is null.
   Fixed upstream in olafkfreund/nixarchy-microvm, then bump the
   `nixarchy-microvm` root input.
5. **Stale hand copies:** move the real directories that shadow the managed
   nixarchy plugins to a backup folder. On p620: microvm, devenv, distrobox,
   flatsnap, podman. On razer: distrobox. winvm stays.
6. **bar-folder:** a `safeDestroy` helper at all four `.destroy()` sites and a
   `root &&` guard at line 155. A local branch in the clone plus an upstream
   PR. Remove omacards, oma-swiss and omaproton-vpn from bar-folder's
   `widgets` and `widgetSettings`.

## Steps

Repo steps (worktree `../nixos-2151`, branch `fix/2151-shell-startup-slow`):

1. `overlays/quickshell-desktopentry-parent-watch.patch` (new), and in
   `overlays/upstream-fixes.nix` lines 133-140 add
   `patches = (old.patches or [ ]) ++ [ ./quickshell-desktopentry-parent-watch.patch ];`
   to the existing `overrideAttrs`.
   - Patch content, against quickshell 0.3.1 `src/core/desktopentrymonitor.{hpp,cpp}`:
     - Add a member `QHash<QString, QString> canonical` (desktop path →
       canonical path), filled in `startMonitoring()`.
     - Add a `QSet<QString> appDirs` holding every path added through
       `scanAndWatch()`.
     - `onDirectoryChanged(path)`: if `appDirs` contains `path`, run
       `debounceTimer.start()`. Otherwise, for each desktop path compare
       `QFileInfo(p).canonicalFilePath()` with the stored value; if any differ,
       call `startMonitoring()` and `debounceTimer.start()`; else return.
   - Generate it from the source tree:
     `nix build --no-link nixpkgs#quickshell.src`, copy it, edit, then
     `diff -u`.

   Verify by `nix build .#nixosConfigurations.p620.pkgs.quickshell` (the
   patch applies and it compiles).
   Traps: the overlay applies to p510 too, so build it but don't deploy p510.
   Don't write a line-initial `#issue` in comments (the formatter turns it
   into a heading).
2. `hosts/common/nixos/omarchy-omamail.nix` (new), following the
   `omarchy-*.nix` fragment shape (`{ pkgs, ... }:` and
   `home-manager.users.olafkfreund.systemd.user.services.omamail-no-restore`):
   - `Unit.Before = [ "graphical-session-pre.target" ]` (deviation: the plan said `graphical-session.target`, but the shell starts from `wayland-wm@`, which is only `After=graphical-session-pre.target`, so the job must hold that target).
   - `Unit.ConditionPathExists = "%h/.config/omamail/window.json"`.
   - `Install.WantedBy = [ "graphical-session-pre.target" ]`.
   - `Service.Type = "oneshot"`.
   - `ExecStart` is a `pkgs.writeShellScript` running
     `${pkgs.jq}/bin/jq '.windowOpen = false' "$f" > "$f.tmp" && mv "$f.tmp" "$f"`.

   Import it in `hosts/p620/nixos/nixarchy.nix` and
   `hosts/razer/nixos/nixarchy.nix`, next to line 37
   (`omarchy-omadroid.nix`).

   Verify by `just check-syntax`, then
   `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.systemd.user.services.omamail-no-restore.Install`.
   Traps: this is a user unit, not a system service, so the
   DynamicUser/ProtectSystem rule doesn't apply (it must write `$HOME`, like
   the gmessages fragment's user service). Keep comments minimal.
3. Remove gmessages:
   - delete line 36 (`omarchy-gmessages.nix`) in both hosts' `nixarchy.nix`;
   - `git rm hosts/common/nixos/omarchy-gmessages.nix pkgs/gmessages-omarchy -r`;
   - delete `pkgs/default.nix:57`.

   Verify by
   `grep -rn gmessages --include=*.nix . | grep -v '^./\(intent\|spec\|plan\)/'`
   (empty).
   Traps: explicit imports only; check that nothing else imports the file.
4. Build: `just test-host p620` and `just test-host razer` (and
   `just test-host p510`, build only). Commit steps 1-4 as
   `fix(desktop): ... (#2151)`, with the prose in a file passed to `git commit -F`.
   Traps: the bus guard greps command text for deploy words, so write
   messages via files.

Upstream plugin fixes (other repos; no commits to this repo except the bump):

1. olafkfreund/nixarchy-microvm: branch `fix/focus-dead-context`. At the top
   of `focusForMode()` in `MicrovmView.qml` (line 126), add
   `if (!Model) return`. Open a PR, merge it, then
   `nix flake update nixarchy-microvm` here and commit the lock as
   `chore(flake): bump nixarchy-microvm for the focus fix (#2151)`.

   Verify by the plugin repo's own checks, if it has any, plus the p620
   build.
2. bar-folder (`~/.config/omarchy/plugins/io.github.arikisonfire.bar-folder`,
   a clone of arikisonfire/omarchy-bar-folder): branch `fix/teardown-destroy`.
   - Add `function safeDestroy(o) { if (o && typeof o.destroy === "function") o.destroy() }`.
   - Use it at lines 95, 117-118 and 139-140.
   - Line 155: `root && root.shell ? root.shell.barConfig : ({})`.

   Commit, fork, push and open a PR upstream. The local clone stays on the
   branch until upstream merges.

Runtime steps (user state, outside the repo; on p620, then razer):

1. Deploy: post on the bus, then switch p620 from `main` after the PR merges,
   and `just deploy-via-p620 razer`.
2. Per host, before restarting the shell:
   - Back up `~/.config/omarchy/shell.json` to
     `~/.local/state/omarchy-plugin-backup/shell.json.<date>`.
   - Move the stale `nixarchy.*` directories (decision 5) into that folder.
   - `omarchy plugin remove glasschan.oma-swiss --yes`, and the same for
     `io.github.grichard99.omaproton-vpn` and `io.github.jxsparrou.spokenshelf`
     (p620 only; razer has no spokenshelf). Use `rm -r` for any it won't
     remove.
   - Delete the `.*.bak*` directories.
   - With jq on `shell.json`, remove omacards, oma-swiss and omaproton-vpn
     from bar-folder's `widgets` and `widgetSettings`, and spokenshelf from
     `disabledPlugins`.
   - Re-run the HM activation (`systemctl restart home-manager-olafkfreund`) so
     the managed nixarchy plugins are linked, then log out and back in.

   Traps: the shell rewrites `shell.json` itself, so edit it with the session
   logged out (from tty or ssh) or restart the shell straight after. The
   Omarchy shell PID check over ssh must match the Nix wrapper (`pgrep -f Hyprland-wrapped`), not `pgrep -x Hyprland`.

## Tests

- `just check-syntax`, `just test-host p620`, `just test-host razer`: pass.
- After logging in on p620:
  - `qs log -r '*.debug=true'` shows ≤ 5 "Directory change detected" in the
    first 2 min (50 before).
  - `journalctl --user -t owed` shows "shell background enabled" ≤ 10 s
    after the session start (61 s before).
  - `touch ~/x; rm ~/x` adds no rescan.
  - Adding a `.desktop` to `~/.local/share/applications` still shows in the
    launcher.
- Omamail: leave its window open, log out and back in. It doesn't open, the
  bar envelope count shows, and clicking opens the inbox.
  `journalctl --user -u omamail-no-restore` ran before `omarchy-shell`.
- Plugins:
  - `ls ~/.config/omarchy/plugins` shows no removed plugins and no `.bak`
    directories.
  - The `nixarchy.{microvm,devenv,distrobox,flatsnap,podman}` entries are
    symlinks.
  - A fresh shell log shows no `focusTarget`, `FolderService` or omacards
    errors.

## Rollback

- Repo: revert the PR's squash commit and redeploy.
- Plugins: copy the directories and `shell.json` back from
  `~/.local/state/omarchy-plugin-backup/`.
- bar-folder: `git -C <clone> checkout main`.
- microvm: revert the lock bump.
