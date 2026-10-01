---
status: draft
issue: 2122
author: olafkfreund
---

# Intent: launcher entries per Chrome profile

## Problem

Google Chrome holds three separate profiles: google.com (personal),
Synechron (work) and freundcloud.com. Opening a specific one today means
starting Chrome, which opens whichever profile was used last, and then
switching through the profile menu. There is no way to go straight to a
profile from the Omarchy launcher or the GNOME app grid.

Chrome's on-disk profile directories are not the same on each host:

| Profile         | p620        | razer                         |
| --------------- | ----------- | ----------------------------- |
| google.com      | `Default`   | `Profile 2` (named "Privat")  |
| Synechron       | `Profile 3` | `Profile 3`                   |
| freundcloud.com | `Profile 4` | `Profile 5`                   |

So a launcher that hard-codes one directory opens the wrong profile, or a
fresh empty one, on the other host.

## Proposed outcome

On p620 and razer, the app launcher (Super+Space in Omarchy, the GNOME app
grid) lists three entries — "Chrome — google.com", "Chrome — Synechron",
"Chrome — freundcloud.com". Each opens a Chrome window already in that
profile; if Chrome is running it opens a new window in that profile rather
than a second browser. On razer, "google.com" opens the "Privat" profile.
Entries can be pinned to the GNOME dock.

## Affected users and systems

- Hosts: p620 and razer (Home Manager, user olafkfreund). p510 is untouched:
  Chrome is disabled there.
- Files: a new Home Manager module under `home/desktop/`, plus the per-host
  profile mapping in `Users/olafkfreund/p620_home.nix` and `razer_home.nix`.
- Chrome itself and its existing per-host flags (`programs.chromium`) are not
  changed.

## Constraints

- Must launch the Chrome that `programs.chromium` already wraps with each
  host's flags (Wayland/ANGLE settings differ per host), not a bare package.
- Must not modify Chrome profiles or `~/.config/google-chrome`.
- Desktop icons on the desktop surface are not possible: neither
  Omarchy/Hyprland nor GNOME draws them. "Desktop icon" means the launcher
  entry and, optionally, a dock pin.
- Explicit imports only; the module is imported by path.

## Open questions

1. Icons: use each profile's Google account picture where Chrome stores one
   (google.com and freundcloud.com have one; Synechron does not), or the
   plain Chrome icon for all three? Proposed: account pictures, falling back
   to the Chrome icon.
2. Hyprland cannot tell the three apart (all windows are class
   `google-chrome`). Accepting that for now is proposed; separating them is a
   separate task if wanted.
