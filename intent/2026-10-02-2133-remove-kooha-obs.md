---
status: draft
issue: 2133
author: olafkfreund
---

# Intent: Remove Kooha and OBS Studio

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

## Open questions

1. **v4l2loopback on p620 and razer.** Both load three loopback devices
   labelled "OBS Virtual Cam 1", "OBS Virtual Cam 2" and "COSMIC Camera"
   (`hosts/*/nixos/boot.nix`), and `webcam.enable` carries the comment
   "OBS Virtual Camera support". Without OBS, is anything still writing to
   those devices (droidcam, a meeting tool, the old COSMIC camera)? Options:
   remove v4l2loopback entirely, or keep it and only drop the OBS labels.
2. **`kdenlive`** is mentioned next to OBS in `overlays/upstream-fixes.nix`
   (qtmultimedia comment). That comment only needs rewording; keep kdenlive
   unless you want it gone too.
