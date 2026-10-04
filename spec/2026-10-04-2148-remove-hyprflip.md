---
status: draft
issue: 2148
intent: intent/2026-10-04-2148-remove-hyprflip.md
---

# Spec: remove hyprflip from p620 and razer

## Design

Undo the Issue #2003 trial and the hyprflip/OmaCards features outright, rather
than switching back to an older hyprflip state:

- `flake.nix`: delete the `hyprflip` input and the `omacards` input, with
  their comment blocks. `nix flake lock` then drops the hyprflip subtree
  (its Hyprland, nixpkgs e554fab and their children) and `omacards`. No
  other node changes.
- Delete `hosts/common/nixos/hyprland-from-hyprflip.nix`. It forced
  `programs.hyprland.package` to hyprflip's Hyprland on p620 and razer.
  Without it, nixarchy's default applies: `inputs.nixarchy.inputs.hyprland`
  (Hyprland main, bc82253), whose nixpkgs is our `c59305b`, so its glibc
  2.44 matches mesa.
- Delete `hosts/common/nixos/omarchy-hyprflip.nix`. It wrote
  `~/.config/hypr/hyprflip.lua` and installed the OmaCards plugin and
  helpers. It is only active when `programs.hyprflip.enable` is set, and
  nothing else references it.
- `hosts/p620/nixos/nixarchy.nix`: remove the imports of
  `hyprland-from-hyprflip.nix`, `inputs.hyprflip.nixosModules.default` and
  `omarchy-hyprflip.nix`, and the `programs.hyprflip` block, plus its
  comment. Reword the `portalPackage` comment, which named the trial.
- `hosts/razer/nixos/nixarchy.nix`: remove the
  `hyprland-from-hyprflip.nix` import and reword the same comment.
- `hosts/common/nixos/omarchy-sole-hyprland.nix`: reword the comment that
  said p620 and razer force hyprflip's Hyprland.

The SDDM greeter, the session launcher and `omarchy-sole-hyprland.nix` all
read `programs.hyprland.package`, so dropping the one override moves all of
them together.

## Alternatives rejected

- **Keep hyprflip and add `inputs.hyprland.inputs.nixpkgs.follows =
  "nixpkgs"`** (one line, built and evaluated first). It fixes the glibc
  mismatch, but Hyprland and the plugins would no longer be cached, so they
  build locally on every bump. It also keeps a second Hyprland lineage that
  can diverge from nixarchy's again. The user chose removal.
- **`nix flake update hyprflip`.** hyprflip's upstream lock still pins
  nixpkgs e554fab (2026-09-17), so this changes nothing.
- **Follow the switch-back steps in `hyprland-from-hyprflip.nix`** (restore
  `inputs.hyprland.follows = "nixarchy/hyprland"` and keep the plugin). That
  keeps a feature the user wants gone, and the plugin still has to match
  the compositor build.
- **Pin mesa or set `LD_LIBRARY_PATH` for Hyprland.** That fights the
  symptom, and breaks again at the next mesa or glibc bump.

## Risks

- Losing the hyprflip cards, hy3 containers and the OmaCards panel on p620
  and razer. This is intended.
- `~/.config/hypr/autostart.lua` (user-owned) still requires
  `hypr.hyprflip`. It does so through `pcall`, so the missing file is
  ignored. A bare `require` would have dropped the session into the error
  overlay.
- A stale OmaCards backup directory
  (`~/.config/omarchy/plugins/.io.github.nocstah.omacards.bak-1973`) is
  left behind. It is hidden and inert.
- Hyprland moves from ae50c4d to bc82253 (Hyprland main, two days apart).
  This is the build p510 already runs.
- razer's session keeps the old compositor until it next restarts. That
  restart is when the new build is exercised.

## Verification

- `nix flake lock` reports only removed inputs, and `comm` over the old and
  new `locked.rev` sets shows no new revs.
- `just test-host p620` and `just test-host razer` build.
- `ldd <hyprland>/bin/.Hyprland-wrapped | grep libc.so` shows
  `glibc-2.44`, and `nix-store -qR` of the p620 toplevel has no hyprflip
  paths.
- p620: after switching and restarting `display-manager`, the greeter
  session appears on seat0 with Hyprland running and no new crash report or
  coredump.
- razer: `/run/current-system` is the built path, no failed units,
  `/etc/hyprflip` is absent, and its Hyprland links glibc 2.44.
