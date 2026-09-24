---
status: approved
issue: 2003
author: olafkfreund
---

# Intent: p620 runs the Hyprland that hyprflip has verified, with the cached plugins

Tracked as olafkfreund/nixos_config#2003.

## Problem

Hyprflip now has a nightly job (olafkfreund/nixarchy-hyprflip#6). It moves the
Hyprland lock in hyprflip's `flake.lock` to the newest `main` only after the
plugin and hy3 build and pass `nix flake check`. It then pushes both to
`nixarchy.cachix.org`.

This config is wired the other way round (`flake.nix`, the `hyprflip` input):

- `nixarchy.inputs.hyprland.url = "github:hyprwm/Hyprland/main"` (the
  aquamarine CRTC fix) tracks the tip of `main`.
- `hyprflip.inputs.hyprland.follows = "nixarchy/hyprland"` builds the plugin
  against that same commit.

That causes two problems:

1. **Rebuilds fail whenever the two commits differ.** Hyprflip's build checks
   that the Hyprland it gets is the commit named in *its own* `flake.lock`. A
   `nix flake update` moves our Hyprland to the tip of `main` immediately, while
   hyprflip's lock only moves after a green night, and not at all on a night
   when Hyprland broke the plugin. On any such day the p620 rebuild fails. Today
   both locks happen to be at `e368c13`, so it works by coincidence.
2. **The cache is never used.** `hosts/p620/nixos/nixarchy.nix` does not set
   `programs.hyprflip.package`, so the module rebuilds `hyprflip` and `hy3`
   locally against the system's own packages. That gives a different store
   path from the one on `nixarchy.cachix.org`, so every update compiles both.

## Proposed outcome

- p620 runs Hyprland `main` at exactly the commit hyprflip's nightly job last
  verified, and loads the `hyprflip` and `hy3` builds from that same night.
- A p620 rebuild downloads both plugins from `nixarchy.cachix.org` and the
  compositor from `hyprland.cachix.org`, with no local compile.
- `nix flake update hyprflip` moves the compositor and the plugins together. A
  mismatch between them is no longer possible.
- p620 keeps a Hyprland at or past aquamarine 0.15.1 (the fix for the flapping
  third head), because hyprflip tracks `main`.

## Affected users and systems

- `flake.nix`: the `nixarchy` and `hyprflip` inputs, and `flake.lock`.
- `hosts/p620/nixos/nixarchy.nix`: `programs.hyprflip`.
- **Every host built from nixarchy (p620, razer, p510)**, if the change is made
  on `nixarchy.inputs.hyprland`. That is a flake-level input, and nixarchy sets
  `programs.hyprland.package` from it (`modules/nixos.nix:965`).
- `hosts/common/nixos/omarchy-hyprflip.nix`, which only loads
  `/etc/hyprflip/*.so`, stays unchanged.

## Constraints

- Keep the plugin's commit and ABI checks. A mismatch must still fail the
  build, never the session.
- Keep the aquamarine fix on every host that has it today.
- Build and compare with `nixos-rebuild build` first. Switching p620's live
  session is a separate step that needs your go-ahead, and it rolls back with
  the previous generation.
- No change to hyprflip's repository.

## Decisions (answered at intent review)

1. **Scope:** p620 and razer only, as a trial for a period, after which you
   decide. `nixarchy.inputs.hyprland` stays as it is, so p510 and nixarchy's own
   settings are untouched. The per-host override is the mechanism.
2. **Reversible in code:** the override carries a comment saying exactly how to
   switch back.
