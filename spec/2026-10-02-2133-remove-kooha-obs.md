---
status: draft
issue: 2133
intent: intent/2026-10-02-2133-remove-kooha-obs.md
---

# Spec: Replace Kooha and OBS Studio with Omareel

## Design

Three parts: remove, package, install. Evaluated today, Kooha, OBS and the
`webcam` feature are on for p620 and razer and off for p510.

### 1. Remove Kooha, OBS and their leftovers

- Delete `home/desktop/obs/` and `home/desktop/kooha/`, and their imports in
  `home/desktop/default.nix` and `home/profiles/{developer,server-admin}/default.nix`.
- Feature flags: drop `desktop.obs` from `Users/common/features.nix`,
  `Users/common/features-impl.nix` and `Users/olafkfreund/profile.nix`. The
  `kooha` flag is renamed to `omareel` (see part 3), not just dropped.
- Host overrides: drop `programs.obs.enable` from
  `hosts/p620/home-manager-options.nix` and `features.programs.obs` from
  `hosts/razer/home-manager-options.nix`.
- System package sets: drop `obs-studio` from the `media` set in
  `modules/packages/sets.nix` and the `media.obs` line from
  `modules/nixos/packages/categories/desktop.nix`.
- v4l2loopback: delete the module, its package and the modprobe options from
  `hosts/p620/nixos/boot.nix` and `hosts/razer/nixos/boot.nix`. The only
  thing left that would write to a loopback device is `droidcam`, installed
  by `modules/webcam/default.nix`. It is useless without one, so it is
  dropped from that package list. `better-adb-sync` stays, so
  `webcam.enable` stays, and its "OBS Virtual Camera support" comments in
  `hosts/p620/nixos-options.nix` and `hosts/razer/configuration.nix` are
  removed. `media.droidcam` (nixpkgs' own module, which brings its own
  loopback) is already off everywhere and is left alone.
- kdenlive is not installed anywhere. The `(kdenlive, obs)` comment in
  `overlays/upstream-fixes.nix` becomes "every Qt program on the host".
- Docs: `docs/applications/screensharing_cosmic.md:171` points at OBS, so
  that sentence points at Omareel instead. No nav change.
- p510 files (`hosts/p510/nixos/boot.nix`, `hardware-configuration.nix`) are
  not touched. Their v4l2loopback blacklist and commented-out lines change
  nothing at runtime.

### 2. Package Omareel: `pkgs/omareel/default.nix`

`stdenv.mkDerivation` from `fetchFromGitHub` at tag `v0.1.0`, registered in
`pkgs/default.nix` next to `glab-tui`.

- Build: `cmake`, `ninja`, `pkg-config`, `wayland-scanner`,
  `qt6.wrapQtAppsHook`. Inputs: `qt6.{qtbase,qtdeclarative,qtmultimedia,qtsvg,qtshadertools}`,
  `kdePackages.layer-shell-qt`, `libevdev`, `libjpeg_turbo`, `wayland`,
  `wayland-protocols`. Upstream needs Qt ≥ 6.8, and nixpkgs has 6.11.2.
- `postPatch` swaps two hard-coded `/usr` paths:
  - In `CMakeLists.txt`, `/usr/share/wayland-protocols` becomes
    `${wayland-protocols}/share/wayland-protocols`.
  - In `src/core/OmarchyPaths.cpp`, `/usr/share/omarchy/themes` becomes
    `/run/current-system/sw/share/omarchy/themes`, which exists on nixarchy.
    Without this the theme-wallpaper backgrounds are empty.
- The main build sets `-DOMAREEL_BUILD_HYPRLAND_PLUGIN=OFF`, and the plugin
  is built as its own derivation (next bullet).
- Plugin: in the same file, `hyprlandPlugins.mkHyprlandPlugin hyprland`
  builds `plugin/`, with
  `-DOMAREEL_HYPRLAND_HEADERS=${hyprland.dev}/include/hyprland`. It produces
  `omareel-capture-exclude.so` plus a `.hash` file holding the Hyprland
  commit taken from that `version.h`.
- Wrapper (`qtWrapperArgs`):
  - It sets `OMAREEL_PLUGIN_PATH` to the plugin `.so`. Omareel otherwise
    looks next to its binary and in `/usr/lib`.
  - It puts `ffmpeg`, `gpu-screen-recorder` and `slurp` on PATH using
    `--suffix`, not `--prefix`. That way the system's `gpu-screen-recorder`
    (the capability wrapper Omarchy's recorder already uses) still wins.
  - `hyprctl` is deliberately not pinned: it must be the running
    compositor's own binary.
- `hyprland` is a package argument. The default is `pkgs.hyprland`, and the
  install site always overrides it.

### 3. Install Omareel where Kooha was

- `home/desktop/kooha/` becomes `home/desktop/omareel/default.nix`, with the
  option `desktop.screenshots.omareel.enable`. It installs
  `pkgs.customPkgs.omareel.override { hyprland = osConfig.programs.hyprland.package; }`.
  That is the compositor each host actually runs: hyprflip's on p620 and
  razer, nixarchy's on p510. This is what makes the plugin's hash match the
  running Hyprland.
- The `kooha` feature flag is renamed to `omareel` everywhere it appears:
  `Users/common/features.nix`, `features-impl.nix`, `profile.nix` (`= true`),
  and the `developer` and `server-admin` profiles (`true`/`false`). The
  result is installed on p620 and razer, not on p510.
- No keybinding is added. `~/.config/hypr/*.lua` is user-managed runtime
  config, and the README gives a one-line `o.bind` for it. The user is
  already in the `input` group, which click/key capture needs.

## Alternatives rejected

- **Plugin built against `pkgs.hyprland`.** Its commit differs from
  hyprflip's on p620 and razer, so Omareel would refuse to load the plugin
  ("needs rebuilding for this Hyprland commit").
- **Building with the plugin off.** The intent requires the bar and camera
  bubble to stay out of the video. Without the plugin, Omareel moves them to
  another monitor, and on razer's single screen they would be recorded.
- **Waiting for nixarchy to package it.** Nothing upstream packages it yet.
- **Keeping v4l2loopback with neutral labels.** The approver chose removal.
- **Dropping `webcam.enable` entirely.** It still installs `better-adb-sync`.
  Removing that is out of scope.

## Risks

- **The plugin build is tied to the Hyprland source API.** A Hyprland bump
  that breaks `CaptureExclude.cpp` fails the whole host build on p620 and
  razer. If that happens, set the plugin to `null` in the package, which
  takes one line. Omareel then falls back to moving the overlays off the
  recorded screen.
- **Mismatch until re-login.** Between a deploy and the next re-login, the
  running compositor is still the old commit, so Omareel refuses the plugin
  until you log in again. That failure is graceful and is how it behaves by
  design.
- **The upstream project is young.** It is at v0.1.0, has 5 stars and has
  had no commits since 2026-09-05. Expect rough edges, and that version
  bumps will be manual.
- **Native capture is unverified.** It uses `ext-image-copy-capture-v1`. If
  Hyprland 0.56 does not offer it, Omareel uses `gpu-screen-recorder`
  automatically. The runtime check below covers it.
- **Removing v4l2loopback changes the kernel module set on p620 and razer.**
  It takes effect at the next boot, or on switch once the module is no
  longer loaded. Any app that silently used `/dev/video1`, `/dev/video2` or
  `/dev/video10` would lose it. None is known.

## Verification

1. `just check-syntax`, then `just test-host p620`, `just test-host razer`,
   and a build-only `just test-host p510` (no deploy).
2. Closure check on p620 and razer: `nix path-info -r` of the toplevel
   contains no `kooha`, `obs-studio`, `obs-` plugin or `v4l2loopback`, and
   does contain `omareel`. p510's closure contains none of them.
3. Plugin hash: the `.hash` file in the plugin output equals `GIT_COMMIT_HASH`
   in `osConfig.programs.hyprland.package.dev` for that host.
4. Runtime on p620 after a deploy and re-login (deploying is the user's
   call):
   - `omareel record --region` records and stops.
   - `hyprctl plugin list` shows the omareel plugin.
   - The recording bar is absent from `screen.mp4`.
   - `omareel export <bundle> -o /tmp/t.mp4` produces a playable file.
