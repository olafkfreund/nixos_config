---
status: draft
issue: 2148
author: olafkfreund
---

# Intent: remove hyprflip from p620 and razer

Tracked as olafkfreund/nixos_config#2148. This was an incident fix, written up
after the fact: by agreement with the user, the change shipped first (PR #2149,
merged at 5ab2d61d9, deployed to p620 and razer on 2026-10-04) and this file
records it for approval.

## Problem

After p620 restarted on 2026-10-04, Hyprland would not start. It failed in
both the SDDM greeter and the Omarchy session, leaving the machine with no
desktop. Both aborted in the same way:

    ERR from aquamarine ]: Couldn't open a GBM device at fd 39
    CRIT from aquamarine ]: Cannot open backend: no allocator available

p620 and razer had been running hyprflip's Hyprland since the Issue #2003
trial. hyprflip pins its own Hyprland, and Hyprland pins its own nixpkgs
(e554fab, 2026-09-17, glibc 2.42). The system's graphics driver comes from our
nixpkgs (c59305b: mesa 26.2.3, built against glibc 2.44), and its
`dri_gbm.so` needs `GLIBC_2.43`. A process running glibc 2.42 can't load it.
The GPU and device permissions were fine: the same libgbm opened the device
when tested under glibc 2.44.

The failure only appeared at the restart. The previous session had been
running since 2026-09-24, from before the nixpkgs bump (Issue #2118) that
moved mesa, so the breakage sat latent on both hosts for ten days. razer
would have broken the same way at its next restart.

More broadly, the hyprflip trial meant running a compositor that is not built
from our nixpkgs. That has gone wrong more than once, and the user's verdict
is that it "has been nothing but trouble". The value of rotating cards does
not justify the risk of losing the desktop.

## Proposed outcome

- p620 and razer start Hyprland again, in both the greeter and the Omarchy
  session.
- p620 and razer run nixarchy's Hyprland, the same build as p510, built from
  our nixpkgs, so its glibc always matches the system mesa.
- Nothing from hyprflip or OmaCards remains in the flake, the host configs or
  the system closures: no inputs, modules, `/etc/hyprflip` or managed
  `~/.config/hypr/hyprflip.lua`.

## Affected users and systems

- p620 and razer: compositor build, SDDM greeter, Omarchy session, and the
  hyprflip/hy3 plugins and OmaCards bar panel (all lost).
- p510: unaffected. It never ran hyprflip and already used nixarchy's Hyprland.
- `flake.nix` / `flake.lock`: the `hyprflip` and `omacards` inputs.
- The user's own files outside the repo: `~/.config/hypr/autostart.lua` keeps
  a now-dead `pcall(require, "hypr.hyprflip")`, which is harmless.

## Constraints

- No other flake input may move. The lock change must only remove nodes.
- p510 is not built or deployed.
- Deploys are announced on the agent bus first.
- Removing the feature must not break evaluation on razer or p510, which
  import the shared `omarchy-*` fragments.

## Open questions

None. The user chose removal over keeping hyprflip with a `nixpkgs` follows.
