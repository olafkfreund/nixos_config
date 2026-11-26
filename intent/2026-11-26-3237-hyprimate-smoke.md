---
status: approved
issue: 3237
author: olafkfreund
---

# Intent: hyprimate window animations, Liquid by default, on p620 and razer

Approved by the owner (2026-11-26): "set duration to 200 on open and close and lets use Liquid animation for all
hosts. commit and merge and deploy"; then, asked, "p620 + razer" and "Fast-track, cite me". The style is Liquid,
not Smoke; the slug keeps its first name.

## Problem

Opening, closing and moving a window on the Omarchy session uses Hyprland's stock animations. The owner wants the
[hyprimate](https://github.com/JustinBacher/hyprimate) plugin's Liquid style instead, on both desktops. Today it exists
only as a hand-loaded test on p620 that is gone at the next login.

Observed in the 2026-11-26 live test on p620 (AMD), as background, not design:

- hyprimate 0.1.0 (upstream `9e667f9`) built against nixarchy's Hyprland pin (`64bde62`) gives the same Hyprland store
  path as the running compositor and passes the plugin's own post-link symbol check.
- Loaded by hand, it ran Swarm, Liquid, Bubble and Smoke, switched live; the owner reported Swarm "worked perfectly".
- Omarchy does not read `~/.config/hypr/hyprland.lua`, so whatever loads the plugin must hang off a file the session
  does load.
- razer was not tested.

## Proposed outcome

After a deploy and a fresh login on p620 and razer, hyprimate loads with no manual command, and windows open, close and
move with the Liquid style, opening and closing in 200 ms.
Turning the host's flag off and logging in again gives the stock animations back.

## Affected users and systems

- Hosts: p620 (AMD) and razer (hybrid Intel/NVIDIA), both on the same nixarchy Hyprland. Not p510.
- User: `olafkfreund`'s Omarchy session on those hosts.

## Constraints

- The plugin is built against the exact Hyprland the session runs, following nixarchy's pin, never its own.
- Declarative only: no `hyprpm`, no hand-made files in `~/.config/hypr`.
- Off unless a host enables it: p510, also an Omarchy desktop, must not pick it up through a shared template.
- A plugin runs inside the compositor, so a crash ends the session. Two recovery paths must exist: the flag plus a
  re-login for a running desktop, and booting the previous generation (or a TTY rebuild) if the session dies at login.
- A switch or a config reload in a running session must never load a second, newly built copy of the plugin into the
  older compositor. A new plugin takes effect at the next login.
- Anything forced for the plugin (Hyprland's `decoration.wobble` conflicts with it; it is off today) applies only
  while the plugin is enabled.
- Upstream is young (0.1.0, one author, daily commits): pin a rev, bump deliberately.
- p510 is not built or deployed.

## Decisions (owner, 2026-11-26)

1. **Style and timing:** Liquid, `duration = 200` for opening and closing; other Liquid settings at upstream defaults.
2. **Rollout:** p620 and razer together. p510 stays out.
3. **Breakage on a Hyprland bump:** not answered; the recommended default stands. A plugin that no longer builds fails
   the host build and blocks that upgrade (razer's guarded upgrade simply does not switch); the fix is a hyprimate bump
   or turning the flag off. No automatic drop.

## Open questions

None.
