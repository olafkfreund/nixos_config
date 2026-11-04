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
- **Two layouts have no key.** Hyprland 0.57 ships four tiled layouts:
  dwindle, scrolling, master and monocle. Omarchy's SUPER+L
  (`omarchy-hyprland-workspace-layout-toggle`) cycles only dwindle →
  scrolling → floating, and no other key switches layouts. Master and
  monocle are installed, but reaching them takes a hand-typed `hyprctl`
  command.
- **The wanted arrangement doesn't exist.** The user wants one large window
  on the right with the other windows stacked small in a column on the left.
- **Every layout setting is either Omarchy's default or hand-edited.**
  Nothing about layouts can be reviewed, reproduced or shared through the
  repo or through nixarchy.

## Proposed outcome

- **Same default on p620 and razer.** On both hosts, every workspace without
  a saved SUPER+L choice starts in `scrolling` after a deploy, whatever Atmos
  or the seeded files say.
- **Big window on the right.** Switching a workspace to master puts one large
  window on the right and stacks the others in a column on the left. A new
  window joins the left stack, and the big window stays where it is. The big
  window starts at a set share of the width and can still be resized.
- **One key reaches master and monocle.** It cycles the current workspace
  through scrolling, master and monocle, and the choice is saved the same
  way SUPER+L saves its choice. SUPER+L is unchanged in this task: on a
  master or monocle workspace it moves to dwindle, as it does today for any
  layout outside its cycle.
- **Layout-specific keys.** Inside each layout, a few keys do its common
  moves:
  - master: swap with the big window, grow or shrink it
  - scrolling: resize or swap columns
  - monocle: cycle windows
- **Declared in the repo.** All of this is in this repo, shared by p620 and
  razer.

Out of scope here, as a follow-up issue in nixarchy once this works locally:
a supported way to load layout settings after `looknfeel`, and SUPER+L
cycling master and monocle. When that lands, the extra key here can be
retired.

## Affected users and systems

- **Hosts:** p620 and razer, the Omarchy desktop session only. p510 is not
  touched.
- **Repo:** the shared Omarchy host config used by p620 and razer.
- **User files:** `~/.config/hypr/` and the saved layout choices under
  `~/.local/state/omarchy/workspace-layouts/` on both hosts.
- **nixarchy:** only through the follow-up issue.

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
   has 1, 2, 6, 24. Keep them, or clear them so those workspaces also start
   in scrolling? Clearing loses those preferences. If cleared, it is a
   one-time manual step at rollout, never something every rebuild repeats.
   No proposal: your call.

The exact key, the big window's starting width and the file layout are
design choices for the spec.
