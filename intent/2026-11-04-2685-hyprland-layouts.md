---
status: draft
issue: 2685
author: olafkfreund
---

# Intent: declarative Hyprland layouts, scrolling default, master-right

## Problem

- **No layout is declared in this repo, and the two desktop hosts disagree.**
  - p620 runs `scrolling`. The only place that sets it is the block Atmos
    manages in the mutable `~/.config/hypr/looknfeel.lua`.
  - razer runs Omarchy's default, `dwindle`, because the same line in its
    `looknfeel.lua` is commented out.

  A theme change, a reinstall or a new host can therefore change the layout
  without the repo knowing.
- **Two layouts can't be reached.** Hyprland 0.57 ships four tiled layouts:
  dwindle, scrolling, master and monocle. Omarchy's SUPER+L
  (`omarchy-hyprland-workspace-layout-toggle`) cycles only dwindle →
  scrolling → floating, so master and monocle are installed but no key
  reaches them.
- **The wanted arrangement doesn't exist.** The user wants one large window
  on the right with the other windows stacked small in a column on the left.
- **Every layout setting is either Omarchy's default or hand-edited.**
  Nothing about layouts can be reviewed, reproduced or shared through the
  repo or through nixarchy.

## Proposed outcome

- **Same default everywhere.** p620 and razer both start every workspace in
  `scrolling` after a deploy, whatever Atmos or the seeded files say.
- **Big window on the right.** Switching a workspace to master puts one large
  window on the right and stacks the others in a column on the left. A new
  window joins the left stack, and the big window stays where it is.
- **One key reaches master and monocle.** It cycles the current workspace
  through scrolling, master and monocle, and the choice is saved the same
  way SUPER+L saves its choice. SUPER+L keeps working as it does now.
- **Layout-specific keys.** Inside each layout, a few keys do its common
  moves:
  - master: swap with the big window, grow or shrink it
  - scrolling: resize or swap columns
  - monocle: cycle windows
- **Declared in the repo.** All of this is in this repo, shared by p620 and
  razer.
- **Upstreamed to nixarchy.** A follow-up PR there adds:
  - a supported load point for a user `hypr/layouts.lua` after `looknfeel`
  - SUPER+L also cycling master and monocle

## Affected users and systems

- **Hosts:** p620 and razer, the Omarchy desktop session only. p510 is not
  touched.
- **Repo:** a new shared file under `hosts/common/nixos/` (the
  `omarchy-input.nix` pattern), imported by both hosts' `nixarchy.nix`.
- **User files:** `~/.config/hypr/` on both hosts. One file becomes
  Home Manager-managed.
- **nixarchy:** a separate PR in that repo.

## Constraints

- **Scrolling stays the daily default.**
- **Atmos keeps working.** Its block in `looknfeel.lua` stays writable, and the
  repo-managed layout settings must still win over it.
- **Saved SUPER+L choices keep working.** These are the per-workspace files
  under `~/.local/state/omarchy/workspace-layouts/`, and they keep overriding
  the default for their workspace.
- **No clash with Omarchy's existing keys.** SUPER+CTRL+L (lock) and
  SUPER+SHIFT+M (Spotify) are taken.
- **Settings equal to Omarchy's defaults are not restated.**
- **Deploys:**
  - announce on the agent bus before deploying
  - deploy razer via p620
  - never touch p510
- **Desktop rules:** Hyprland 0.57 Lua config only (`hl.*`), loaded from
  Omarchy's store `hyprland.lua`. Read `docs/architecture/desktop.md` before
  editing.

## Open questions

1. **Old saved layout choices.** The saved per-workspace choices predate this
   change: p620 has 1, 3, 13, 14, 22 (dwindle) and 4, 5 (scrolling); razer
   has 1, 2, 6, 24. Should they be cleared so every workspace starts in
   scrolling, or kept? **Proposed:** clear them once on deploy.
2. **Which key cycles scrolling/master/monocle?** **Proposed:** SUPER+SHIFT+L,
   which is free on both hosts.
3. **How big is the big window?** **Proposed:** 65% of the width.
4. **Should the nixarchy upstream PR be part of this task or a follow-up
   issue in nixarchy?** **Proposed:** a follow-up, after this works locally.
