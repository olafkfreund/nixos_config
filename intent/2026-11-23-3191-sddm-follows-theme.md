---
status: approved
issue: 3191
author: olafkfreund
---

# Intent: the SDDM login screen follows the Omarchy theme

## Problem

Changing the Omarchy theme (`omarchy theme set <theme>`, or the theme menu) recolours the desktop live: GTK,
Qt, icons, kitty, the bar and the wallpaper (#2370). The SDDM login screen does not change. It shows the same
Tokyo Night look whatever theme is active:

- nixarchy enables SDDM and selects its `omarchy` theme (`services.displayManager.sddm.theme = "omarchy"` in
  nixarchy's `modules/nixos.nix`). SDDM loads that theme read-only from the Nix store, at
  `share/sddm/themes/omarchy`.
- The theme's `Main.qml` hardcodes the background colour `#1a1b26`.
- Everything else visible is a fixed PNG:
  - the Omarchy logo (`logo.png`);
  - the lock icon (`lock.png`, `lock-failed.png` after a wrong password);
  - the password-field frame (`entry.png`, `entry-failed.png`);
  - the password bullets (`bullet.png`).
- The screen shows no text. The password input itself is transparent.
- Omarchy's `omarchy-refresh-sddm` (which upstream copies the theme into `/usr/share/sddm/themes`) is a stub
  on NixOS. It says the login theme changes with a rebuild, but no rebuild recolours it either, because the
  theme has no notion of the active Omarchy theme.

So after a theme change, the screen before and after every session does not match the desktop.

## Proposed outcome

After a theme change, the next login screen SDDM shows (after a logout or a reboot) matches the active theme:

- the background uses the theme's background colour;
- the logo, lock icon, field frame and bullets use colours from the theme's palette, legible on both dark and
  light themes;
- the wrong-password state stays clearly distinct;
- whether the wallpaper is shown, and how the logo is handled, are open questions (below).

Proposed: no rebuild is needed, as with the rest of a theme change. This is pending the owner's answer to
question 1. A machine whose theme has never been changed, or whose theme data cannot be used, shows today's
look.

## Affected users and systems

- **Hosts:** p620, razer and p510. All three have one user, `olafkfreund`, run Omarchy with nixarchy's SDDM,
  and import `hosts/common/nixos/omarchy-sddm.nix` (Hyprland as the greeter compositor).
- **Code:**
  - nixarchy's `omarchy` SDDM theme;
  - the nixarchy module that selects it;
  - whatever carries the theme data to the greeter (decided in the spec).
- **People:** the owner, at every login, and every other nixarchy user if the change goes into nixarchy.

## Constraints

- **The greeter cannot read the theme:** the greeter runs as the `sddm` user, with no systemd user session.
  The user's home is mode 700 (checked on p620), so the greeter cannot read the active theme where Omarchy
  keeps it.
- **No privilege escalation:** changing a theme runs as the user. Whatever makes the theme visible to the
  greeter must not give the user a general way to write as root, or to place arbitrary files where the greeter
  or other users can read them. A privileged reader of user-owned theme files must not follow symlinks out of
  them or copy anything beyond the theme data.
- **Login always works:** bad theme data must never leave the machine without a usable login screen. That
  covers missing, partial or unreadable data, invalid colour values, an unreadable image, and a QML error.
  SDDM gives up after six failed greeter starts and leaves the host with no login manager (see
  `hosts/common/nixos/omarchy-sddm.nix`), so a failure must fall back to today's look inside the same greeter,
  not crash it.
- **Leave the live theme pipeline alone:** no Stylix Home Manager gtk, gnome or kde targets, and no dconf
  writers. Those revert a live theme switch at the next activation (#2370).
- **Process:**
  - p510 is never built or deployed without the owner's OK.
  - Announce on the agent bus before any deploy.

## Open questions

1. **When:** must the login screen follow at the next greeter with no rebuild (proposed), or is "at the next
   rebuild" acceptable? Either way, a greeter already on screen keeps its look until it restarts.
2. **Wallpaper:** should the login screen show the theme's current background image, or only colours? If it
   shows the image, should changing just the wallpaper also update it?
3. **Logo and failed state:** should the Omarchy logo be tinted to the theme, kept as is, or hidden? Should a
   wrong password use the theme's red?
4. **Where it lives:** in nixarchy, which ships this theme so every nixarchy user gets it (preferred), or only
   in this repo? If nixarchy, is it on by default or opt-in?
5. **Whose theme:** on these single-user hosts the user's theme is the login theme. For nixarchy's multi-user
   case, should the login screen follow one named user, or stay on the default when there is more than one?
6. **`omarchy-refresh-sddm`:** should it now refresh the login theme, or only have its message corrected?
