---
status: draft
issue: 3028
author: olafkfreund
---

# Intent: Install omateams from the olafkfreund/omateams flake

Predecessor: the omateams repo's own artifacts,
`intent/2026-11-17-nix-flake.md` and `spec/2026-11-17-nix-flake.md`
(olafkfreund/omateams#2, open). The memory cap in this repo is #3021, merged.

## Problem

- **The packaged omateams runs on the buggy QtWebEngine.**
  `pkgs/omateams/default.nix` builds upstream `Divanyx/omateams` at rev
  `e8264d1` against the pinned nixpkgs, whose QtWebEngine is `6.140.0-rc`.
  That version still has QTBUG-142040: after a screen share, libwebrtc
  terminates the EGL display that QtWebEngine's in-process GPU thread also
  uses. This was the suspected cause of the 180 GiB omateams window process
  on p620 on 2026-11-17.
  - #3021's `systemd-run` cap contains the damage, but the bug stays.
  - Today the only escape is a manual restart.
- **The in-app memory guard isn't in what the hosts run.** That guard is
  olafkfreund/omateams#1, merged. It restarts the window process, has a
  10 GiB ceiling, and records every share attempt.
- **The packaging is duplicated.** The fork now ships a flake (#2) with the
  same patches, the same cap, home-manager and NixOS modules, and a pinned
  QtWebEngine 6.140.0. Keeping `pkgs/omateams` too means two copies that
  drift apart.

## Proposed outcome

- p620 and razer run omateams from `github:olafkfreund/omateams`, on
  QtWebEngine 6.140.0 or later, with the in-app memory guard.
- Updating omateams is `nix flake update omateams`, with no rev or hash to
  edit.
- `pkgs/omateams` is gone. omaoutlook still opens Teams invitations in
  omateams.
- After a share, stopping and sharing again no longer logs
  `eglCreateSync failed`, and host memory stays flat. This is checked at
  runtime on p620.

## Affected users and systems

- **Files:** `flake.nix` and `flake.lock` (new input),
  `hosts/common/nixos/omarchy-omateams.nix`,
  `hosts/common/nixos/omarchy-omaoutlook.nix`, `pkgs/default.nix` and
  `pkgs/omateams/`, which goes. `pkgs/omaoutlook` keeps taking an
  `omateams` argument.
- **Hosts:** p620 and razer, which import both modules. p510 doesn't import
  them, and that is to be confirmed in the spec. No p510 build without the
  owner's OK.
- **User:** olafkfreund. The Teams sign-in in `~/.local/share/omateams`
  must survive.

## Constraints

- **Everything the user gets today stays the same:**
  - the plugin is registered through `programs.nixarchy.plugins`, and
    `local.omarchy.enableOnce` turns it on once;
  - the host starts hidden at login (`runInBackground`);
  - the binary is built against `config.programs.hyprland.package`;
  - the `systemd-run` cap is 12G/16G with no swap;
  - omaoutlook's Teams links open omateams.
- **The QtWebEngine 6.140.0 fix must not be lost to `follows`.** The input
  makes `nixpkgs` follow ours, but not `nixpkgs-qt`.
- **No merge until olafkfreund/omateams#2 is merged.** The input can track
  the fork's default branch only once the flake is there. Before that, a
  branch or rev pin is acceptable for testing only.
- **This repo's gates apply:** intent, spec and plan; never work on `main`;
  build p620 and razer here.

## Open questions

1. **Input pin.** Track the fork's default branch, updated with
   `nix flake update`, or pin a rev the way `nixarchy-llm-index` does?
   - The recommendation is to track the branch. The fork is ours, and
     `flake.lock` pins it anyway.
2. **Closure size.** Until `nixos-unstable` reaches QtWebEngine 6.140.0, the
   closure carries a second nixpkgs's Qt set: QtWebEngine and its
   dependencies, all from the cache. Is that acceptable for now?
   - The recommendation is yes, with a follow-up to drop `nixpkgs-qt` once
     unstable catches up.
