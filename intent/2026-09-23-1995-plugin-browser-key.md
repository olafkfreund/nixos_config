---
status: approved
issue: 1995
author: olafkfreund
---

# Intent: Super+Alt+U opens the Plugin Browser again on p620 and razer

## Problem

Super+Alt+U no longer opens the Plugin Browser on p620 or razer.

nixarchy now ships the Plugin Browser (olafkfreund/nixarchy#915): the
plugin, its tools, and the Setup ▸ Plugins ▸ Add Plugin row. #1991 therefore
removed this repo's `hosts/common/nixos/omarchy-plugin-browser.nix`, which
had both overridden that row and written the key file
`~/.config/hypr/plugin-browser-binds.lua`.

Dropping the row override was right. Dropping the key was not, because it
rested on a wrong assumption. nixarchy seeds Super+Alt+U only into a
**new** home's `bindings.lua`, and never edits an existing one (nixarchy
`docs/manual/plugins.md`: "seeded … on new installs. nixarchy never edits
that file afterwards"). p620's and razer's homes are not new.

Found on razer, 2026-09-23, after the #1991 deploy and a re-login:
`hyprctl binds` has **0** bindings for Super+Alt+U, and pressing it opens
nothing. Both hosts' `bindings.lua` still contain
`pcall(require, "hypr.plugin-browser-binds")` (razer line 260, p620 line
353), which now loads nothing, silently.

## Proposed outcome

- On p620 and razer, **Super+Alt+U opens the Plugin Browser**, after the next
  deploy and a re-login.
- If the plugin is turned off, the key says so with a notification instead
  of doing nothing.
- Add Plugin stays nixarchy's own row; this repo does not override it
  again.
- `bindings.lua` stays hand-owned and unedited: the existing `pcall` line
  is what picks the key up.

## Affected users and systems

- **p620 and razer**, through the host modules that imported the old file.
  The change is Home Manager only: one generated lua file.
- **p510:** not affected (it never imported the old module).
- **nixarchy:** unchanged. Its seed already covers new homes.

## Constraints

- **Don't reintroduce the row override.** #1991 was right to drop it: the
  override replaced nixarchy's `when` guard and aliases.
- **Don't edit `~/.config/hypr/bindings.lua`.** It is user-owned. The
  `pcall` line already there is the hook, and `pcall` keeps a rollback that
  drops the file from breaking Hyprland.
- **Deploying p620 or razer follows the usual rules:** announce on the bus,
  diff closures first, and never p510 without asking.
- The binding appears only after a **re-login** (the same as every bind
  and menu change on these hosts).

## Open questions

1. **Where does the file live?** Restore the old module as a key-only
   module, imported again by p620 and razer. Or add the one `home.file`
   line to each host's existing nixarchy Home Manager settings. The
   proposal is the key-only module: one place, the same shape as
   `omarchy-gog.nix`.
