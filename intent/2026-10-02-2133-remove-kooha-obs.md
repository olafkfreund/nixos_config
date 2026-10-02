---
status: approved
issue: 2133
author: olafkfreund
---

# Intent: Replace Kooha and OBS Studio with Omareel

## Problem

Kooha and OBS Studio are installed but the user does not use either, and
will not. OBS comes with 17 plugins, each rebuilt from source with a
`-Werror` workaround (`home/desktop/obs/default.nix`). That costs build time
and closure size, and every OBS or compiler bump risks breaking a build.
Screen recording is already covered by Omarchy's own recorder
(`omarchy-capture-screenrecording`, built on `gpu-screen-recorder`).

## Proposed outcome

Neither `kooha` nor `obs-studio` (nor any OBS plugin) is in any host's
closure. No option, feature flag, module or package-set entry for them is
left in the tree.

Omareel (<https://github.com/omacom/omareel>) is installed on p620 and razer
in their place: a screen recorder and editor for Omarchy with a synthetic
cursor, auto zooms, click effects and a camera bubble. `omareel record`
works from a keybinding, and the Hyprland capture-exclusion plugin loads so
the recording bar and camera bubble stay out of the video.

## Affected users and systems

- Hosts: p620 and razer (both currently have OBS + Kooha). p510 uses the
  `server-admin` profile, where both are already off.
- Home Manager: `home/desktop/obs/`, `home/desktop/kooha/`,
  `home/desktop/default.nix`, `home/profiles/{developer,server-admin}`.
- Feature flags: `Users/common/features.nix`, `features-impl.nix`,
  `Users/olafkfreund/profile.nix`.
- Host overrides: `hosts/p620/home-manager-options.nix`,
  `hosts/razer/home-manager-options.nix`.
- System package sets: `modules/packages/sets.nix` (`media` set),
  `modules/nixos/packages/categories/desktop.nix` (`media.obs`).

## Constraints

- p510 is not built or deployed without asking. Removing the options it
  sets to `false` changes its evaluation, so it must be build-tested, but
  not deployed without approval.
- No other module may still set a removed option, or evaluation fails.

## Decisions (approver, 2026-10-02)

1. v4l2loopback is removed from p620 and razer, not relabelled.
2. kdenlive is removed too. It turns out not to be installed anywhere; only
   a comment in `overlays/upstream-fixes.nix` names it, so that comment is
   reworded.
3. Omareel replaces both, on the hosts that had them (p620, razer).
