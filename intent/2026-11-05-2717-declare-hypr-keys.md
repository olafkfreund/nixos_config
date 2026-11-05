---
status: draft
issue: 2717
author: olafkfreund
---

# Intent: declare and document Hyprland keys and panel layout

## Problem

Keys and panel placement on the Omarchy desktop live partly outside this repo, so they don't survive a fresh install and drift between hosts.

- **Keys in local files.** `~/.config/hypr/bindings.lua` is hand-owned on each host, with about 30 top-level binds on p620, 25 on razer and none on p510. Exposé on SUPER+E, Minimize on SUPER+N, Distrobox on SUPER+ALT+D and Podman on SUPER+ALT+O exist only there. Omgato's keys sit in `omgato-bindings.lua`, generated from local plugin state.
- **Hosts disagree.** p620's `bindings.lua` has Exposé, Govee, Dev environments, Distrobox and Podman, which razer's lacks; razer has no bind that p620 lacks. p620 also loads Omgato, Hyprforge and Meeting AI bind files that razer doesn't.
- **A fresh host would not get the repo's keys.** Several modules write a bind file but rely on a `pcall(require, ...)` line added by hand to `bindings.lua`. Only `omarchy-altscape.nix` adds its own line, and only if the file already exists.
- **Panel placement is local.** On 2026-11-05, p620 had five plugins moved off the top panel by editing `~/.config/omarchy/shell.json`. razer's `shell.json` still places all five there.
- **Menu rows are local.** The Distrobox and Podman rows are in p620's `~/.config/omarchy/extensions/omarchy-menu.jsonc`, and razer has neither.
- **Docs barely cover keys.** Only `docs/architecture/desktop.md`, `docs/applications/agent-voice.md` and `docs/applications/meet.md` mention them, and none of the keys moved in #2714 or added since are documented.
- **A dormant key clash.** p620's `bindings.lua` still loads an optional Hyprforge file, which by its comment uses SUPER+ALT+H and SUPER+ALT+SHIFT+P, which #2714 gave to Nixi and Meeting AI. Hyprforge isn't installed now, so nothing clashes today, but it would if it returned.

Super+K itself is not the gap. `omarchy-menu-keybindings` builds its list from the live config and binds, and on p620 it finds the manual keys. A key declared with a description will appear there.

## Proposed outcome

- The repo holds the agreed set of keys, each with a description, and a rebuild on an Omarchy host produces them with no hand edit to `bindings.lua`.
- p620 and razer have the same shared keys, panel placement and menu rows. Where a host must differ, the repo says so and why.
- MicroVMs, Distrobox, Podman, Dev environments and Plugin Browser are off the top panel on both hosts and open from their keys and the menu.
- A check run on each host compares the declared keys with the Super+K list and with `hyprctl binds`, and fails on a missing key or a duplicate in the normal keymap.
- The docs have one reference for these keys, matching what's declared, and it names any key that stays host-specific.
- A new host that imports the shared config gets the shared keys, panel placement and menu rows after its first login.

## Affected users and systems

- p620 and razer: keys, panel and menu, applied by rebuild.
- p510: unchanged unless the user decides otherwise (question 5). It has no top-level binds in `bindings.lua` today.
- `~/.config/hypr/bindings.lua`, `omgato-bindings.lua`, `~/.config/omarchy/shell.json` and `extensions/omarchy-menu.jsonc` on each host.
- `hosts/common/nixos/omarchy-*.nix` and `docs/`, with nav in both `mkdocs.yml` and `mkdocs-full.yml` if a page is added.
- Plugins and the Plugin Browser, which write to some of these local files themselves.

## Constraints

- Omarchy, its plugins and the Settings UI must keep working, including their live writes to `shell.json` and the menu extension.
- Some keys can't be identical on both hosts. Chrome's work profile is `Profile 4` on p620 and `Profile 5` on razer, and Calendar is an installed app on p620 but a URL window on razer. Copying p620's values creates an empty profile on razer.
- No existing key may lose its bind, and no new duplicate may appear in the normal keymap.
- A plugin or module that's missing or turned off must not break Hyprland's config load, and Super+K must still open without hanging.
- A running session only picks up a new Omarchy tree at login.
- p510 is not built or deployed without asking.

## Open questions

1. **How much of `bindings.lua` moves into the repo?** The user asked for all keys, including manual ones, so the assumption is every top-level bind on p620 and razer. That leaves the Vimarchy submap block (33 `hl.bind` calls, using a plugin path outside Nix): move it too, or leave it local?
2. **Which p620-only keys should razer get?** Exposé, Dev environments, Distrobox and Podman look shared. Govee, Omgato and Meeting AI are currently p620 features, so the assumption is they stay p620 only.
3. **Should Omgato's keys be declared?** Its plugin rewrites `omgato-bindings.lua` when a key changes in its panel, so declaring them could conflict with that panel. The alternative is leaving them plugin-owned and documenting them.
4. **Who wins after a later live change?** If a plugin is turned back on in Settings, or a menu row or key is changed by hand, should the next rebuild restore the repo's version, or should the live change stay?
5. **Does p510 get anything now?** It runs the same desktop, but its role and package set differ. The assumption is that it stays out of this change, apart from evaluating cleanly.
6. **Should Hyprforge's future keys be reserved?** Assumed no: resolve the clash if it comes back, and note it in the docs.
