---
status: draft
issue: 2505
spec: spec/2026-10-27-2505-omateams-plugin.md
---

<!-- markdownlint-disable MD013 -->

# Plan: Microsoft Teams (Synechron) as an Omarchy plugin on p620 and razer

## Decisions carried from the approved spec

- Package omateams 1.4.1 at `e8264d1cf80204679e1f5da7a13a65342a68837d` as
  `pkgs/omateams`: one derivation holding the Qt host app (built from `host/`
  with `qt6.qmake` and `wrapQtAppsHook`, as in the 2026-10-27 test build that
  Synechron accepted), its desktop entry and icon, and the plugin tree under
  `share/omateams/plugin`.
- The plugin never compiles anything. `install.sh` and `uninstall.sh` are not
  shipped. `ui/Service.qml` is patched so `hostBinary` is the store path and
  `Component.onCompleted` runs `checkInstalled()` instead of `ensureHost()`.
- The host app gets `hyprland` (overridden from the system compositor),
  `libnotify`, `coreutils` and `bash` prefixed on its PATH.
- Hosts: p620 and razer. It starts hidden at login (upstream default, so no
  setting). It is enabled once at first login by the shared
  `local.omarchy.enableOnce` module (`hosts/common/nixos/omarchy-enable-once.nix`),
  which lands in #2503.
- Your Teams login and settings stay yours (`~/.local/share/omateams/`,
  `~/.config/omateams/`). Chrome profiles are not touched.

## Dependency

This plan uses `omarchy-enable-once.nix` from #2503. Implement it after #2503
is merged: rebase `feat/2505-omateams-plugin` onto `origin/main` first. If
issue #2503 stalls, step 4 temporarily imports the module from its branch.
That is a deviation, recorded here if it happens.

## Steps

0. **Rebase** `feat/2505-omateams-plugin` onto `origin/main` once #2503 is
   merged.
   → verify: `test -f hosts/common/nixos/omarchy-enable-once.nix`.

1. **`pkgs/omateams/default.nix` (new)**:
   - Args: `{ lib, stdenv, fetchFromGitHub, qt6, makeWrapper, hyprland, libnotify, coreutils, bash }`.
   - `pname = "omateams"; version = "1.4.1";`
     `src = fetchFromGitHub { owner = "Divanyx"; repo = "omateams"; rev = "e8264d1cf80204679e1f5da7a13a65342a68837d"; hash = "sha256-qBL7e/tZeKEG2iZB9WBtTmFbS9+tioMdsO9M8iSXnK0="; };`
     The hash was measured with `nix store prefetch-file --unpack` on the
     archive. If `fetchFromGitHub` disagrees, take the hash from the build
     error. Never invent one.
   - `nativeBuildInputs = [ qt6.qmake qt6.wrapQtAppsHook makeWrapper ];`
     `buildInputs = [ qt6.qtbase qt6.qtdeclarative qt6.qtwebengine ];`
   - `preConfigure = "cd host";`
     `qmakeFlags = [ "OMATEAMS_VERSION=${version}" ];`
   - `postPatch`: `substituteInPlace ui/Service.qml`
     `--replace-fail 'readonly property string hostBinary: (Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")) + "/omateams/bin/omateams"' 'readonly property string hostBinary: "@out@/bin/omateams"'`
     `--replace-fail 'Component.onCompleted: ensureHost()' 'Component.onCompleted: checkInstalled()'`.
     Then, in `postInstall`, `substituteInPlace $out/share/omateams/plugin/ui/Service.qml --subst-var out`.
     (`@out@` isn't known in postPatch, so it is filled in after install.)
   - `installPhase` (the build ran in `host/`):
     `install -Dm755 omateams $out/bin/omateams`;
     `cd ..`;
     `install -Dm644 assets/omateams.desktop $out/share/applications/omateams.desktop`;
     `install -Dm644 assets/omateams.svg $out/share/icons/hicolor/scalable/apps/omateams.svg`;
     `mkdir -p $out/share/omateams/plugin && cp -r manifest.json ui preview.png LICENSE $out/share/omateams/plugin/`.
   - `qtWrapperArgs = [ "--prefix" "PATH" ":" (lib.makeBinPath [ hyprland libnotify coreutils bash ]) ];`
   - `doInstallCheck = true;`
     `installCheckPhase`: `grep -qF "$out/bin/omateams" $out/share/omateams/plugin/ui/Service.qml && grep -qF 'Component.onCompleted: checkInstalled()' $out/share/omateams/plugin/ui/Service.qml && ! test -e $out/share/omateams/plugin/install.sh`.
   - `meta`: MIT, `mainProgram = "omateams"`, `platforms = lib.platforms.linux`.
     A header comment in omapop's style, with
     `# Bump against: gh api repos/Divanyx/omateams/commits --jq '.[0].sha'`.

   → verify: step 2 must be wired first. Then
   `nix build .#nixosConfigurations.p620.pkgs.customPkgs.omateams` builds
   with installCheck passing.
   Traps: `git add` before eval. No `with lib;`. The pre-commit hooks format
   Nix with nixpkgs-fmt.

2. **`pkgs/default.nix`**: after the `omapop` entry, add
   `# Omateams: Microsoft Teams web in an Omarchy-themed window (#2505).`
   `omateams = pkgs.callPackage ./omateams { };`.
   **`.claude/commands/check-updates.md`**: add a row after omapop's,
   `| pkgs/omateams | \`rev\` in \`pkgs/omateams/default.nix\` | \`gh api repos/Divanyx/omateams/commits --jq '.[0].sha'\` |`.
   → verify:`nix eval --raw .#nixosConfigurations.p620.pkgs.customPkgs.omateams.name`
   gives `omateams-1.4.1`.

3. **Smoke test of the built app** (no file edits): in a scratch directory,
   `XDG_DATA_HOME=$d/data XDG_CONFIG_HOME=$d/cfg XDG_CACHE_HOME=$d/cache result/bin/omateams --hidden &`,
   wait 10 s, check that `$XDG_RUNTIME_DIR/omateams/status.json` exists, then
   `result/bin/omateams quit` and `rm -rf $d`.
   → verify: status.json appears, and the process exits after `quit`.
   Traps: closing the window only hides it, so always `quit` (as seen
   2026-10-27).

4. **`hosts/common/nixos/omarchy-omateams.nix` (new)**, as in spec §3:

   ```nix
   { config, pkgs, ... }:
   let
     omateams = pkgs.customPkgs.omateams.override { hyprland = config.programs.hyprland.package; };
   in
   {
     imports = [ ./omarchy-enable-once.nix ];
     home-manager.users.olafkfreund = {
       programs.nixarchy.plugins.omateams.src = "${omateams}/share/omateams/plugin";
       home.packages = [ omateams ];
       local.omarchy.enableOnce = [ "omateams" ];
     };
   }
   ```

   Plus a short header comment in `omarchy-omapop.nix` style: what it is, that
   you sign in once per host, and how to upgrade it.
   If nixarchy's `plugins.<id>.src` rejects a string, use
   `"${omateams}/share/omateams/plugin"` wrapped in
   `builtins.path`/`lib.cleanSource`, or a tiny `runCommand` that symlinks the
   tree, whichever the type accepts.
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src`
   resolves, and the enable-once hook text contains `omateams`.

5. **`hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`**:
   import `../../common/nixos/omarchy-omateams.nix` next to
   `omarchy-omapop.nix`. If #2503's `omarchy-altscape.nix` is already there,
   put it after that.
   → verify: `just check-syntax`.

6. **Build** (no edits): `just validate`, `just test-host p620`,
   `just test-host razer`. p510: `nix eval …p510…toplevel.drvPath` still
   succeeds.

7. **Deploy and live checks** (session model; announce on the bus first):
   merge, fast-forward `~/.config/nixos`, `just p620`,
   `just deploy-via-p620 razer`. Then on each host:
   - run `~/.config/omarchy/hooks/post-boot.d/enable-once` once (the session
     is already up), then a clean `omarchy restart shell`;
   - `omarchy plugin list | grep omateams` shows enabled, and the marker
     exists;
   - `pgrep -a omateams` shows the store-path binary running `--hidden`;
   - `test ! -e ~/.local/share/omateams/bin` (nothing was compiled);
   - exactly one bar;
   - `ps -o rss= -p $(pgrep -o omateams)`, noted now and again after a day.
   - You: click the Teams icon, sign in to Synechron once, check the badge and
     a notification. Restart the shell and check you are still signed in. On
     p620, a test call with camera and mic (Facecam plugged in directly).

## Tests

| Command | Expected |
|---|---|
| `nix build …customPkgs.omateams` | builds; installCheck passes (store path patched, no install.sh) |
| smoke test (step 3) | status.json appears; `quit` exits |
| `just test-host p620` / `razer` | pass |
| after deploy: plugin list, marker, `pgrep` | enabled, marker present, hidden host running from the store |
| `~/.local/share/omateams/bin` | absent |
| sign-in survives a shell restart (you) | yes |

## Rollback

Revert the PR and redeploy. The plugin folder and package disappear, and the
enable-once marker stays, which is harmless. To remove the login too:
`rm -rf ~/.local/share/omateams ~/.config/omateams`. Disable it first with
`omarchy plugin disable omateams` if the shell still lists it.

## Implementation

Seven steps, about five files: per policy, steps 1, 2, 4 and 5 go to one
`coder` agent (Sonnet), started from the worktree directory. Step 0, the smoke
test (3), the builds (6) and the deploy (7) stay with the session model.
Review: a fresh Opus agent given this plan and `git diff`.
