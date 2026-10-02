---
status: approved
issue: 2133
spec: spec/2026-10-02-2133-remove-kooha-obs.md
---

# Plan: Replace Kooha and OBS Studio with Omareel

Work in the worktree `~/.config/nixos-2133`, branch
`chore/2133-remove-kooha-obs`. Never edit `~/.config/nixos`.

## Approved decisions (carried from the spec)

- Remove Kooha, OBS Studio and all 17 OBS plugins, with their HM modules,
  feature flags, host overrides and package-set entries.
- Remove v4l2loopback from p620 and razer. Drop `droidcam` from
  `modules/webcam/default.nix` (useless without loopback), and keep
  `better-adb-sync` and `webcam.enable`. Leave `media.droidcam` and every
  p510 file untouched.
- kdenlive is not installed. Only the `overlays/upstream-fixes.nix` comment
  is reworded.
- Package Omareel v0.1.0 in `pkgs/omareel/`, with the plugin off. The
  wrapper appends ffmpeg, gpu-screen-recorder and slurp to PATH with
  `--suffix`. Never pin `hyprctl`.
- Install it through an HM module that replaces Kooha's
  (`desktop.screenshots.omareel`). The feature flag
  `kooha` becomes `omareel`, so it lands on p620 and razer and not on p510.
- No keybinding is added.
- **Deviation from the spec: no capture-exclusion plugin** (approver,
  2026-10-02). Omareel v0.1.0's plugin targets an older Hyprland API, and it
  does not compile against p620's hyprflip build (`aed4830`): it hits
  `IPC::Socket1::SCommand`, `CLayerSurface::visible`, `CPopup` and the
  renderer transform API. Omareel ships without the plugin, so it moves the
  bar and the camera bubble to another monitor. On razer's single screen,
  use `--no-bar` / `--no-selfview`. Revisit this when upstream releases a
  plugin for the newer API. There is no `hyprland` package argument and no
  `osConfig` override.
- Deviation from the spec: `docs/applications/screensharing_cosmic.md`
  documents COSMIC, and Omareel is Hyprland-only, so the OBS sentence
  becomes generic ("screen recorders") instead of naming Omareel.

## Steps

1. **Package Omareel.**
   - Create `pkgs/omareel/default.nix`, shaped like `pkgs/glab-tui/default.nix`.
   - Args: `lib, stdenv, fetchFromGitHub, cmake, ninja, pkg-config, wayland-scanner,
     qt6, kdePackages, libevdev, libjpeg_turbo, wayland, wayland-protocols,
     ffmpeg, gpu-screen-recorder, slurp`.
   - `src = fetchFromGitHub { owner = "omacom"; repo = "omareel"; rev = "v${version}"; hash = lib.fakeHash; }`.
     Build once, then paste the real hash.
   - Main derivation:
     - `nativeBuildInputs = [ cmake ninja pkg-config wayland-scanner qt6.wrapQtAppsHook qt6.qtshadertools ]`.
     - `buildInputs`: `qt6.{qtbase,qtdeclarative,qtmultimedia,qtsvg}`,
       `kdePackages.layer-shell-qt`, `libevdev`, `libjpeg_turbo`, `wayland`,
       `wayland-protocols`.
     - `cmakeFlags = [ "-DOMAREEL_BUILD_HYPRLAND_PLUGIN=OFF" ]`.
   - `postPatch`:
     - `substituteInPlace CMakeLists.txt --replace-fail /usr/share/wayland-protocols ${wayland-protocols}/share/wayland-protocols`.
     - `substituteInPlace src/core/OmarchyPaths.cpp --replace-fail /usr/share/omarchy/themes /run/current-system/sw/share/omarchy/themes`.
   - No `installPhase`: upstream's CMake installs the binary, the
     `omarecord` symlink, the desktop file and the icons.
   - Wrapper: `qtWrapperArgs = [ "--suffix" "PATH" ":" (lib.makeBinPath [ ffmpeg gpu-screen-recorder slurp ]) ];`
   - `meta`: MIT, linux, `mainProgram = "omareel"`.
   - Register it in `pkgs/default.nix` after `glab-tui` (line 48), with a
     one-line comment: `omareel = pkgs.callPackage ./omareel { };`.
   - Verify:
     - `nix build --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.p620.pkgs.customPkgs.omareel'`
       succeeds.
     - `result/bin/omareel help` runs.
   - Traps:
     - Do not add a flake input. This is a plain `fetchFromGitHub` package.

2. **Swap the Kooha HM module for Omareel.**
   - `git mv home/desktop/kooha home/desktop/omareel`.
   - Rewrite `default.nix` with args `{ pkgs, config, lib, ... }`
     and the option `desktop.screenshots.omareel.enable = mkEnableOption "Omareel screen recorder"`.
     Config:
     `home.packages = [ pkgs.customPkgs.omareel ];`.
   - Update every reference:
     - `home/desktop/default.nix:23` → `./omareel/default.nix`.
     - `home/profiles/developer/default.nix:17,59` and
       `home/profiles/server-admin/default.nix:17,60`: path, and
       `kooha` → `omareel` (comments: "Screen recorder").
     - `Users/common/features.nix:40` → `omareel = mkEnableOption "Enable Omareel screen recording";`.
     - `Users/common/features-impl.nix:56` → `omareel.enable = cfg.desktop.omareel;`.
     - `Users/olafkfreund/profile.nix:102` → `omareel = true;`.
   - Verify: `grep -rn kooha --include=*.nix .` is empty.
   - Traps:
     - Explicit imports only (no `readDir`).
     - `pkgs.customPkgs` must be reachable in HM modules. If it is not,
       check how another HM module uses a customPkgs package, and copy
       that.

3. **Remove OBS.**
   - `git rm -r home/desktop/obs`.
   - Delete:
     - `home/desktop/default.nix:20`.
     - `home/profiles/developer/default.nix:21,63`.
     - `home/profiles/server-admin/default.nix:21,64`.
     - `Users/common/features.nix:44`.
     - `Users/common/features-impl.nix:62`.
     - `Users/olafkfreund/profile.nix:104`.
     - `hosts/p620/home-manager-options.nix:2`.
     - `hosts/razer/home-manager-options.nix:12`.
     - `modules/packages/sets.nix:198` (`obs-studio`).
     - `modules/nixos/packages/categories/desktop.nix:63`.
   - Check `options.packages.*.media.obs` in the categories option
     declarations, and delete it if it is declared.
   - Verify: `grep -rnE "obs-studio|programs\.obs|\bobs(\.enable)? =|media\.obs" --include=*.nix .`
     is empty, ignoring `obsidian`.
   - Traps: line numbers shift after step 2, so match on content, not on
     the number.

4. **Remove v4l2loopback and droidcam-from-webcam.**
   - `hosts/p620/nixos/boot.nix`: delete line 35 (comment) and line 36
     (`boot.kernelModules = [ "v4l2loopback" ];`), and lines 46–50 (comment,
     `extraModulePackages`, `extraModprobeConfig` block).
   - `hosts/razer/nixos/boot.nix:97-102`: delete the same four statements.
   - `modules/webcam/default.nix:19`: drop `droidcam`.
   - Drop the `# OBS Virtual Camera support` comments in
     `hosts/p620/nixos-options.nix:28` and `hosts/razer/configuration.nix:286`.
   - Verify: `grep -rn v4l2loopback hosts/p620 hosts/razer modules` is
     empty.
   - Traps:
     - Before deleting `boot.kernelModules` and `extraModulePackages`,
       check that the lists hold nothing else. If they do, remove only the
       v4l2loopback element.
     - Leave p510 alone.

5. **Reword the comment and docs.**
   - `overlays/upstream-fixes.nix:121`: `(kdenlive, obs)` → `every Qt program on the host`.
     Rewrap the comment.
   - `docs/applications/screensharing_cosmic.md:171`:
     `**OBS Studio and screen recording:** For general screen recording tools like OBS Studio, use the`
     → `**Screen recording:** Screen recorders should use the`.
     Keep the rest of the paragraph.
   - Verify: `just check-syntax`. Markdownlint runs on the whole file at
     pre-push, so clear any existing findings in that file too.
   - Traps:
     - Do not start a line with `#<number>` (the formatter makes it an H1).
     - Keep comments minimal.

6. **Build and verify** (see Tests).
   - Commit each step as `chore(desktop): … (#2133)` with a body file. Never
     put backticks in `-m`.
   - Open the PR linking the intent, the spec and this plan.

## Tests

- `just check-syntax`: passes.
- `just test-host p620`, `just test-host razer` and `just test-host p510`:
  all three build. Build p510 only; do not deploy it.
- Closure check for p620 and razer:

  ```bash
  nix path-info -r ./result | grep -E 'kooha|obs-studio|obs-|v4l2loopback'
  ```

  This prints nothing, and `grep omareel` finds the package. For p510, both greps print nothing.
- Runtime (p620, after the user deploys and logs in again):
  - `omareel record --region` records and stops.
  - With two monitors, the recording bar is placed on the monitor not being
    recorded.
  - `omareel export <bundle> -o /tmp/t.mp4` plays.

## Rollback

- Before merge: close the PR and delete the branch.
- After deploy: `git revert` the merge commit and redeploy, or boot the
  previous generation.
