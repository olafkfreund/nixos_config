---
status: draft
issue: 2306
author: olafkfreund
---

# Intent: the Omarchy bar shows and switches workspace groups

Predecessor: `intent/2026-10-14-2305-directional-window-move.md`, item 5,
split out at its approval.

## Problem

`hosts/common/nixos/omarchy-workspaces.nix` turns SUPER+1..0 into group
switches: group N is workspace N on the first screen, N+10 on the second and
N+20 on the third. Omarchy's stock bar widget
(`share/omarchy/shell/plugins/bar/widgets/Workspaces.qml`, omarchy 4.0.4) only
knows workspace ids 1-10:

- line 26 drops every id above 10, so when the second or third screen has
  focus, the active dot disappears from every bar;
- line 58 marks a number occupied only from ids 1-10, so a group whose
  windows sit only on screen 2 or 3 shows as empty;
- line 35 dispatches `hl.dsp.focus({ workspace = id })` on click, which
  switches the first screen only and leaves the others behind.

## Proposed outcome

On every bar, on every host:

- the dot for the current group is lit whichever screen has focus;
- a number shows as occupied if any screen has a window in that group;
- clicking a number switches all screens to that group, the same as SUPER+N.

On a host with one screen (razer, p510) the widget behaves exactly as stock.

## Affected users and systems

- The Omarchy bar on p620 (three screens), razer and p510.
- `hosts/common/nixos/omarchy-workspaces.nix`, whose group switch the click
  has to reach.
- The stock widget, shipped by the nixarchy flake input.

## Constraints

- Plain QML/Lua; no compiled Hyprland plugin.
- Survive nixarchy/omarchy bumps without silently reverting to the stock
  widget, or fail visibly when the upstream file changes under a patch.
- Do not break the other service-backed bar widgets (a third-party bar
  replacement did, see upstream #12648).
- p510 is never built or deployed without asking.

## Open questions

1. **Delivery.** Patch the stock `Workspaces.qml` in the omarchy package
   (one overlay, every bar, breaks loudly when upstream changes the lines), or
   ship a separate widget as a user Omarchy bar plugin and swap it in the bar
   layout (no package rebuild, but a second copy of the widget to keep in step
   with upstream)? My recommendation is the patch; the spec will confirm it
   applies cleanly and does not cost a large rebuild.
2. **How the click reaches the group switch.** The switcher lives in
   `workspace-groups.lua`; the spec must find how a QML click can call it
   (a dispatcher, an `hl.dsp.exec_cmd`, or exporting it as a named Lua
   function).
3. **Upstream.** Is it worth offering Omarchy a generic hook (for example a
   configurable id→label map) instead of carrying a patch? Out of scope here
   unless you want it.
