---
status: draft
issue: 1894
author: olafkfreund
---

# Intent: install the nixarchy-distrobox plugin on p620 and razer

## Problem

`nixarchy.distrobox`, the keyboard-driven Omarchy plugin for distrobox, is merged
(olafkfreund/nixarchy-distrobox#2), but no host installs it declaratively.

- **On p620** it runs today as a hand-copied directory at
  `~/.config/omarchy/plugins/nixarchy.distrobox`, left over from development.
  That copy is not pinned, not rebuilt, and not validated at rebuild time.
- **On razer** it is not installed at all.

The same three hosts already install nixarchy-pkg through a flake input and
`programs.nixarchy.plugins."<id>".src` (`flake.nix:120-131`,
`hosts/p620/nixos/nixarchy.nix:140`, `hosts/razer/nixos/nixarchy.nix:113`).
distrobox itself is already on both hosts (`home/development/distrobox.nix`),
and so is podman.

## Proposed outcome

- A flake input `nixarchy-distrobox` that follows this flake's `nixpkgs`.
- p620 and razer set `programs.nixarchy.plugins."nixarchy.distrobox".src` to
  its package. After a rebuild, the plugin is a store link that nixarchy
  validates, in place of the hand copy.
- The distrobox glyph shows on the bar of both hosts, and
  `omarchy-shell shell toggle nixarchy.distrobox '{}'` opens the menu.

## Affected users and systems

- **Files:** `flake.nix` and `flake.lock` (a new input),
  `hosts/p620/nixos/nixarchy.nix`, and `hosts/razer/nixos/nixarchy.nix`.
- **p620:** deployed locally.
- **razer:** deployed with `just deploy-via-p620 razer`.
- **Not p510.** It is left out, because this repo never builds or deploys
  p510 without asking first.

## Constraints

- **Mirror the nixarchy-pkg wiring exactly.** Same comment shape, and no
  module of our own. nixarchy's option installs the plugin but does not enable
  it; enabling is runtime state in `shell.json`.
- **The hand copy blocks the link.** nixarchy will not replace a real
  directory at the plugin path, so the p620 copy must be removed right before
  the switch. Removing it drops the widget for the few seconds until the
  switch re-links it; `shell.json` keeps its enabled entry.
- **Someone else's pending change.** The working tree already has an
  uncommitted `flake.lock` change: a bump of the `nixarchy-pkg` input. It is
  not part of this task. It must not be committed under this issue, and it
  must not be lost.
- Build-test before any deploy (`just test-host`, `just validate`).

## Open questions

1. **The pending `flake.lock` bump of `nixarchy-pkg`.** Should I keep it out
   of this branch (stash it, and restore it afterwards), or include it here,
   as its own separate commit?
2. **Keybind.** Should this change also add `SUPER + ALT + D` to each host's
   bindings, or leave keys to you as the nixarchy-pkg wiring does? Default:
   leave it, and document it in a comment.
3. **Enabling on razer.** Enabling is one `omarchy plugin enable
   nixarchy.distrobox` per machine. Should I run it on razer over SSH after
   the deploy? Default: yes, since it only edits razer's `shell.json`.
