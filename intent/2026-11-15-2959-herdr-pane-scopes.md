---
status: approved
issue: 2959
author: olafkfreund
---

# Intent: one runaway herdr pane must not take the whole session down

Owner approval: "work on the last 2 issues and close them all" (2026-11-15).

## Problem

On 2026-11-15 20:42 p620 ran out of memory (243/270 GB RAM, swap 100%). systemd-oomd killed the kitty scope that
started herdr. All herdr panes are children of the herdr server inside that one cgroup, so the kill stopped the
server and about 14 agent sessions at once.

## Proposed outcome

Each pane's shell runs in its own systemd scope, so oomd picks the runaway pane's cgroup and the herdr server and
the other panes survive.

## Affected users and systems

herdr on p620 and razer (Home Manager, `home/development/herdr.nix`). p510 gets it at its next owner-approved deploy.

## Constraints

- herdr's agent detection must keep seeing the pane's processes: the shell is exec'd in place.
- Without a user bus (SSH, remote panes) the pane starts a plain shell.
- No memory limits are added; only the cgroup boundary changes.

## Open questions

None.
