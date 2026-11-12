---
status: draft
issue: 2874
author: olafkfreund
---

# Intent: Remove gogmail from the config

## Problem

GogMail, the keyboard-driven Google Workspace TUI from
`github:olafkfreund/gogmail`, is no longer used; something else has replaced it.
It is still a flake input and is still installed on every host that loads
the tmux Home Manager config. So each eval and update fetches, locks and
builds a package nobody runs, and tmux still offers it through a keybind and
two menus. Its comments also tell readers it is the way to reach Gmail.

Where it lives today (`origin/main`):

- `flake.nix:197-202`: the `gogmail` input and its comment
- `flake.lock`: the `gogmail` node and its transitive inputs
- `overlays/default.nix:8`: `pkgs.gogmail`
- `home/shell/tmux/default.nix`: `pkgs.gogmail` and the `gogmail-tmux`
  wrapper in `home.packages` (618-637), the `M-c` bind (194-197), the
  `m` entry in the which-key menu (514-516), the "GogMail (Popup)" entry
  in the AI-tools palette (608-613), and a status-bar comment (365-366)
- Comments that name it: `home/shell/gogcli/default.nix:25,90`,
  `modules/secrets/api-keys.nix:206`, `pkgs/gogcli/default.nix:24-28`

## Proposed outcome

- `git grep -i gogmail` finds nothing outside the `intent/`, `spec/` and
  `plan/` files for this task.
- `gogmail` and `gogmail-tmux` are absent from every host's closure, and
  `flake.lock` has no `gogmail` node.
- tmux no longer has `M-c` bound or a GogMail menu or palette entry.
- All three hosts evaluate and build with no new warnings.

## Affected users and systems

- p620 and razer: the developer Home Manager profile that imports
  `home/shell/tmux`. Check p510, which may also load it.
- The owner's tmux muscle memory: `M-c` stops doing anything.
- `olafkfreund/gogmail#29` (the stdenv fix opened earlier today) becomes moot.

## Constraints

- **The `gog` CLI stays.** `programs.gogDashboard`, `pkgs/gogcli`, the
  `gogcli-*` agenix secrets and the `gog` skill all still use it. Comments
  there are reworded, not removed with the code.
- Explicit imports only, no new options (AGENTS.md).
- p510 is not built or deployed without the owner's OK.
- Deploys follow the bus-announce rule.
- No secret is deleted. `gogcli-keyring-password` is still read by
  `gog-token-import` and `gogWrapped`.

## Open questions

1. Should `M-c` be rebound to the replacement tool, or just unbound? If
   rebound, which command?
2. Should the `olafkfreund/gogmail` repo be archived on GitHub, and
   `gogmail#29` closed? (Left untouched unless you say so.)
3. Should anything in `~/.config/gogmail` or similar user state be cleaned
   up on the hosts, or left alone? (Default: left alone; Nix does not own it.)
