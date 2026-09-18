---
status: draft
issue: 1896
author: olafkfreund
---

# Intent: install the nixarchy-microvm plugin and its SUPER+ALT+V bind on p620 and razer

## Problem

`nixarchy.microvm` is the keyboard-driven Omarchy plugin for NixOS MicroVMs
(olafkfreund/nixarchy-microvm#1). It is built and verified on its feature
branch, but no host installs it declaratively.

- **On p620** it runs as a hand-copied directory at
  `~/.config/omarchy/plugins/nixarchy.microvm`, left over from development.
  Its key, `SUPER + ALT + V`, comes from a hand-written
  `~/.config/hypr/microvm-binds.lua`, which `bindings.lua` loads with
  `pcall(require, "hypr.microvm-binds")`.
- **On razer** it is not installed at all, and there is no bind.

The plugin's flake now ships both halves:

- the package, for `programs.nixarchy.plugins."<id>".src`, the same as
  nixarchy-pkg and nixarchy-distrobox (#1894);
- `homeManagerModules.default`, which writes `~/.config/hypr/microvm-binds.lua`
  (`programs.nixarchy-microvm.keybinding`, default `SUPER + ALT + V`). This is
  the same fragment pattern as `omarchy-meet-binds.nix` and ai-mirror.

## Proposed outcome

- A flake input `nixarchy-microvm` that follows this flake's `nixpkgs`.
- p620 and razer set `programs.nixarchy.plugins."nixarchy.microvm".src`, and
  import the plugin's Home Manager module with the default chord.
- On both hosts:
  - the MicroVMs glyph shows on the bar;
  - `SUPER + ALT + V` opens the menu;
  - Super+K lists "MicroVMs" on that chord.
- razer's `bindings.lua` gains the one `pcall(require, "hypr.microvm-binds")`
  line that p620's already has.

## Affected users and systems

- **Files:**
  - `flake.nix` and `flake.lock` (a new input);
  - `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`;
  - possibly a small `hosts/common/nixos/` module, if that is where Home
    Manager imports for these hosts belong. The spec decides.
- **p620:** deployed locally.
- **razer:** deployed with `just deploy-via-p620 razer`, then set up over SSH
  (`omarchy plugin enable nixarchy.microvm`, plus the `bindings.lua` line).
- **Not p510.**

## Constraints

- **Mirror the #1894 wiring.** Same comment shape, and no module of our own
  beyond importing the plugin's. Enabling a plugin stays runtime state in
  `shell.json`.
- **Two hand copies on p620 block the switch.** The plugin directory blocks
  nixarchy's link, and the hand-written `microvm-binds.lua` makes Home Manager
  refuse to overwrite it. Remove both right before the switch.
- **Not ours to commit.** The working tree already has two uncommitted
  changes that are not part of this task. Neither may be committed under this
  issue, and neither may be lost:
  - a `flake.lock` bump of `nixarchy-voice`;
  - staged `hosts/p620/nixarchy/{apps,services}.nix` lines for `p1`, a test
    VM from the plugin's live checks. These will be removed when those checks
    finish.
- `bindings.lua` is user-owned on both hosts. It gets exactly one `pcall`
  line and nothing else.
- Build-test before any deploy (`just test-host`, `just validate`).

## Open questions

1. **Input ref.** The plugin is not merged yet. Proposal: wait for
   nixarchy-microvm's PR to merge and point the input at `main`. The
   alternative is to pin `?ref=feat/1-microvm-plugin` now and repoint after
   the merge.
2. **The two uncommitted changes.** Proposal: keep both out of this branch.
   Stash the `flake.lock` bump and restore it afterwards. The `p1` lines stay
   staged until the plugin's live checks remove them.
3. **razer over SSH.** After the deploy, run `omarchy plugin enable
   nixarchy.microvm` and add the `pcall` line to razer's `bindings.lua`?
   Default: yes, since both touch only razer's own user config.
4. **The microvm service on razer.** The plugin manages disposable VMs
   without it; permanent VMs need `programs.nixarchy.services.microvm`.
   Default: leave the service off on razer. Turning it on is the user's
   choice from the plugin (`c` → permanent → `a`).
