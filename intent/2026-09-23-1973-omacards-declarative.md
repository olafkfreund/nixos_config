---
status: approved
issue: 1973
author: olafkfreund
---

# Intent: declare OmaCards on p620, with its Hyprflip helper and shortcuts

## Problem

OmaCards (the Omarchy bar plugin `io.github.nocstah.omacards`) works on p620, and
since #1967 it has multi-app cards. Everything that makes it work outside the
compositor was set up by hand on 2026-09-22 and lives outside this repo:

1. **The plugin** is a hand `git clone` at
   `~/.config/omarchy/plugins/io.github.nocstah.omacards`, commit `97a331e`. It is
   pinned nowhere. `omarchy plugin update` can move it to an unreviewed commit,
   and a re-install or a new home loses it silently: the bar icon disappears.
2. **The helper OmaCards runs** (`python3 ~/.local/lib/hyprflip/control.py`) is
   three files copied by hand from the `nixarchy-hyprflip` fork. A bump of the
   `hyprflip` input moves the Hyprland plugin and hy3, but not the helper. OmaCards
   checks the helper's protocol (it requires `1`) only at runtime. A mismatch
   shows up in the panel as "Update the Hyprflip helper", never at build time.
3. **OmaCards' own shortcuts are missing:** Super+Ctrl+Alt+C (edit a card), L
   (open a saved card) and Space (peek). Upstream installs them with Hyprflip's
   `install-setup.py`. That script was deliberately not run, because it rewrites
   `~/.config/hypr/`. Its Lua (`examples/containers-setup.lua`) also calls a
   fourth helper file, `setup.py`, which was never copied.

## Proposed outcome

On p620, after a rebuild:

- OmaCards comes from a pinned revision declared in this repo, through
  `programs.nixarchy.plugins`, the pattern `omarchy-gmessages.nix` and
  `omarchy-microvm.nix` use. The bar entry stays where it is.
- The helper files come from the same pinned `hyprflip` input as the Hyprland
  plugin, so one input bump moves the plugin, hy3 and the helper together.
- A helper protocol that OmaCards does not accept fails the **build**, not the
  panel.
- Super+Ctrl+Alt+C, L and Space work and are declared in this repo.
- Everything else behaves as today: the bar, the existing Hyprflip binds, hy3 on
  workspace 8, and the Omarchy shell keybindings.

## Affected users and systems

- **p620 only**, where OmaCards and `programs.hyprflip` live. razer and p510 are
  not affected and must still evaluate.
- The Omarchy shell (a plugin change reloads every plugin, ~40 s bar freeze), the
  Hypr Lua config managed by `hosts/common/nixos/omarchy-hyprflip.nix`,
  `~/.config/omarchy/plugins/`, and `~/.local/lib/hyprflip/`.

## Constraints

- **Cutover trap.** nixarchy's plugin activation never replaces a real directory
  under a declared id. It prints `is your own directory, not replacing it` and
  keeps the hand clone, so the declared version would silently never apply. The
  hand clone has to be moved aside (kept as a backup, not deleted) at switch
  time.
- **Nothing to lose today:** the clone has no local changes and there are no
  saved cards (`~/.local/state/hyprflip/` does not exist). This must be
  re-checked at cutover, because cards made before then live in that state
  directory and must survive.
- **The O key.** Upstream's setup module rebinds Super+Ctrl+Alt+O from #1967's
  "unfold" to "unfold, fold or create a card". Declaring it must not leave two
  binds fighting over O.
- **Stacked work.** This builds on `omarchy-hyprflip.nix` from #1967 (PR #1972)
  and on #1969. It merges after both. Another agent (2973f4) is adding an import
  line to the same `hosts/p620/nixos/nixarchy.nix` list.
- **No `hyprctl reload`** on the live session, and no `omarchy plugin update`
  against a Nix-managed plugin afterwards.
- **`~/.local/lib` is not syncthing-managed**, so Home Manager links there are
  safe. `~/.claude` and `~/.gemini` are the syncthing traps, and they are not
  involved.

## Open questions

- **Pin source for OmaCards:** a flake input (`flake = false`, bumped with
  `nix flake update`) or `fetchFromGitHub` with a hash in the module?
  Recommendation: a flake input, so it shows in lock bumps and `check-updates`
  like every other plugin input.
- **The O key:** take upstream's combined "unfold, fold or create a card" (it
  replaces #1967's unfold-only bind), or keep #1967's? Recommendation: take
  upstream's, since it is a superset.
- **`omarchy plugin update` after the cutover:** it would try to update a
  read-only store link. Is a note enough, or should the plugin be marked
  non-updatable if nixarchy supports that? Recommendation: a note, and the spec
  checks what nixarchy offers.
