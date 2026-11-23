---
status: draft
issue: 3191
author: olafkfreund
---

# Intent: the SDDM login screen follows the Omarchy theme

## Problem

Changing the Omarchy theme (`omarchy theme set <theme>`, or the theme menu) recolours the desktop live: GTK, Qt, icons, kitty, the bar and the wallpaper, through hyprchroma (#2370). The SDDM login screen does not change. It always shows Tokyo Night, whatever theme is active:

- nixarchy selects SDDM's `omarchy` theme (`services.displayManager.sddm.theme = "omarchy"`), which ships read-only in the Nix store.
- Its `Main.qml` hardcodes the background colour `#1a1b26`.
- The lock icon, the password field and the bullet are fixed PNGs.
- Omarchy's own `omarchy-refresh-sddm` is a stub on NixOS that says the theme changes only with a rebuild, and even a rebuild does not change it.

So after a theme change, the first and last screen of a session (login, and the greeter after logout) does not match the desktop.

## Proposed outcome

After a theme change, the next time SDDM shows (logout, reboot, or a user switch), the login screen uses the active theme:

- the background colour, text colour and accent come from the theme's `colors.toml`;
- the lock icon, password field and bullet are drawn in those colours rather than Tokyo Night;
- whether the wallpaper is shown behind the form is an open question (below).

No rebuild is needed for this, as with the rest of the live theme pipeline. A fresh install, or a host whose user has never changed theme, still shows a sensible default.

## Affected users and systems

- **Hosts:** p620, razer and p510, all of which greet with SDDM through Omarchy (`hosts/common/nixos/omarchy-sddm.nix`).
- **Code:**
  - nixarchy's `omarchy` SDDM theme (`share/omarchy/default/sddm/omarchy`);
  - the module that selects it (`modules/nixos.nix` in nixarchy);
  - the user's `theme-set.d` hook path.
- **People:** the owner, at every login.

## Constraints

- **Reading the theme:** the greeter runs as the `sddm` user. `$HOME` is mode 700, so it cannot read `~/.local/state/omarchy/current/theme`. Anything it reads must be copied out to a place it can read, and must stay in sync with the active theme.
- **No secrets, nothing private:** only colours (and possibly a wallpaper) are copied out. Nothing from the user's home that isn't theme data.
- **Privileges:** a theme change runs as the user. Writing outside `$HOME` for the greeter must not hand the user a general root path. Either a narrow, fixed-purpose helper or a system unit that reads the theme.
- **Live theme rules:** don't break the live theme pipeline (`project-live-theme-pipeline`): no Stylix HM gtk, gnome or kde targets, no dconf writers.
- **Failure:** a broken or missing theme copy must fall back to the current look, never to a greeter that can't log in.
- **Placement:** nixarchy owns the theme, so a fix that benefits every nixarchy user belongs there, as a carried change or an option. Whether part of it lives in this repo instead is open (below).
- **Process:** p510 is deployed only with the owner's OK. Bus announcement before any deploy.

## Open questions

1. **When it applies:** live, at the next greeter with no rebuild (the proposal), or is "at the next rebuild" acceptable? The rebuild route is simpler, but it is not what the theme menu does elsewhere.
2. **Wallpaper:** should the login screen show the theme's current background image, or only its colours?
3. **Where it lives:** in nixarchy, for every user (preferred, since nixarchy ships the theme), or only in this repo?
4. **Which user's theme wins:** these hosts have one desktop user, so the last theme set wins. Is that right, or should it follow a named user?
