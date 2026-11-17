---
status: approved
issue: 3028
author: olafkfreund
---

# Intent: Install omateams from the olafkfreund/omateams flake

Predecessor: the omateams repo's own artifacts,
`intent/2026-11-17-nix-flake.md` and `spec/2026-11-17-nix-flake.md`
(olafkfreund/omateams#2, open). The memory cap here is #3021, merged.

## Problem

- **The hosts run omateams on a QtWebEngine with a screen-share bug.**
  `pkgs/omateams/default.nix:21-29` builds upstream `Divanyx/omateams` at
  `e8264d1` against the pinned nixpkgs's `qt6`.
  - That nixpkgs (`f5c082a`) has QtWebEngine `6.140.0-rc`. This was checked
    on 2026-11-17 with `nix eval`.
  - On code.qt.io, the `v6.140.0-rc` tag's Chromium still calls
    `EglTerminate(egl_.display)` in libwebrtc's `egl_dmabuf.cc`. The
    `v6.140.0` tag doesn't.
  - That call is QTBUG-142040. After a screen share it terminates the EGL
    display that QtWebEngine's in-process GPU thread also uses.
  - It is the **suspected** cause of the 180 GiB window process on p620 that
    day. How a terminated display turns into unbounded growth is not
    established.
- **The fixes aren't in what the hosts run.**
  - olafkfreund/omateams#1 (merged) adds an in-app memory guard. It restarts
    the window process instead of only warning, has a 10 GiB ceiling, and
    records every share attempt.
  - #3021's cap only ends the process when the kernel steps in.
- **The packaging is duplicated.** olafkfreund/omateams#2 ships a flake
  with the same packaging as `pkgs/omateams`, plus home-manager and NixOS
  modules. It builds on QtWebEngine 6.140.0: its `nix flake check` passes,
  and `ldd` shows only `qtwebengine-6.140.0`. Two copies of the packaging
  will drift apart.

## Proposed outcome

- **p620 and razer run the fork's omateams,** with the in-app guard, on
  QtWebEngine 6.140.0 or later.
- **One copy of the packaging,** maintained in the fork, and updating
  omateams needs no hand-edited rev or hash.
- **Memory stays bounded after a screen share** on p620. Sharing, stopping
  and sharing again logs no `eglCreateSync failed`. Host memory doesn't grow
  without bound, or the guard restarts the process.
- **Both hosts work as before.** On p620 and razer, omateams starts, is
  signed in, and shows its bar widget.

## Affected users and systems

- **Files:** `flake.nix`, `flake.lock`,
  `hosts/common/nixos/omarchy-omateams.nix`,
  `hosts/common/nixos/omarchy-omaoutlook.nix`, `pkgs/default.nix`,
  `pkgs/omateams/` and `pkgs/omaoutlook/` (through its `omateams`
  argument).
- **Hosts:** p620 and razer. They are the only hosts that import either
  module (`hosts/p620/nixos/nixarchy.nix:46-49`,
  `hosts/razer/nixos/nixarchy.nix:43-45`). p510 imports neither.
- **User:** olafkfreund. The Teams sign-in in `~/.local/share/omateams`
  must survive.

## Constraints

What the user gets today must keep working:

- **Declarative install.** Nix installs omateams, and the plugin doesn't
  install a host itself at runtime.
- **The plugin and the bar widget.**
  - The plugin is registered with nixarchy and turned on once per host.
  - The bar widget's colour fallback (#2778) stays.
  - The host starts hidden at login unless `runInBackground` is off.
- **The desktop entry and icon.**
- **The host's Hyprland.** omateams uses the host's own Hyprland tools on
  its `PATH`, from `config.programs.hyprland.package`.
- **The memory cap.** The host runs in the `systemd-run` scope (12G high,
  16G max, no swap) whenever the user bus exists, and falls back to an
  unscoped start without one, as today.
- **omaoutlook.** Teams invitations opened in omaoutlook keep opening in
  omateams.
- **The Qt fix survives our nixpkgs.** Following our nixpkgs must not bring
  back the unfixed QtWebEngine.
- **Ordering.** This doesn't merge before olafkfreund/omateams#2.
- **This repo's gates apply.** Never work on `main`, and build p620 and
  razer here.

## Open questions

1. **Input pin.** Track the fork's default branch, with `flake.lock` pinning
   the rev, or pin a rev in the URL the way `nixarchy-llm-index` does? The
   recommendation is to track the branch, since the fork is ours.
2. **Extra closure cost.** Until our nixpkgs reaches QtWebEngine 6.140.0,
   the fork pins a second nixpkgs for its Qt.
   - Checked on 2026-11-17: its `qtbase-6.12.0` is the same store path we
     already have, and its `qtwebengine-6.140.0` is in cache.nixos.org.
     So the cost is mostly one more QtWebEngine on disk, and nothing to
     build.
   - Is that acceptable until our nixpkgs catches up? The recommendation is
     yes.
