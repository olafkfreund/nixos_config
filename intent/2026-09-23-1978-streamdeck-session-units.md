---
status: approved
issue: 1978
author: olafkfreund
---

# Intent: Stream Deck daemons follow the graphical session

## Problem

On p620 the Stream Deck MK.2 goes dead after every re-login: buttons fire, but
nothing happens on screen.

The two omgato daemons, `streamdeck-ctl-deck.service` (deck) and
`streamdeck-ctl.service` (pedal), are user units that omgato's
`scripts/install` wrote by hand into `~/.config/systemd/user/`. They are
`WantedBy=default.target` with only `After=graphical-session.target`, so they
start with the user manager and survive logout. They keep the environment of
the first session they saw (`OMARCHY_PATH`, no `WAYLAND_DISPLAY` or
`HYPRLAND_INSTANCE_SIGNATURE`), and every button press then execs `omarchy-*`
commands at a shell tree and compositor that no longer exist.

Neither the units nor the binary are in this repo. `~/.local/bin/streamdeck-ctl`
links to `target/release/streamdeck-ctl` in the omgato plugin clone
(`~/.config/omarchy/plugins/io.github.data-goblin.omgato`, 0.1.7), built by hand
with `nix-shell -p pkg-config systemdLibs libusb1`. A new home directory or a
re-install loses the lot.

Today's workaround is `systemctl --user restart streamdeck-ctl-deck streamdeck-ctl`
after every login.

## Proposed outcome

- Logging out stops both daemons. Logging in starts them fresh in the new
  session's environment. Nobody restarts anything by hand.
- The units are declared in this repo, so a fresh home gets them.
- The hand-installed units in `~/.config/systemd/user/` are gone, so there are
  no duplicates.

## Affected users and systems

- p620 only (Stream Deck MK.2 + Facecam Pro). razer and p510 have no deck.
- Home Manager user config for olafkfreund on p620.
- The omgato Omarchy plugin (upstream data-goblin/omgato). It stays installed
  and managed by `omarchy plugin`, because the bar UI and deck profiles live
  there.

## Constraints

- Must not change razer or p510.
- Must not break the omgato plugin's own UI or config (`~/.config/omgato`).
- Home Manager is a flake module: no `home-manager switch`.
- Deploying p620 restarts user units. Announce it on the agent bus first.

## Open questions

1. **Where the binary comes from.** Options:
   (a) package omgato as a Nix derivation (`pkgs/omgato`, a Rust build pinned to
   a release) and point the units at the store path; or
   (b) keep the hand-built binary in the plugin clone and only declare the
   units, still at `%h/.local/bin/streamdeck-ctl`.
   (a) is reproducible, but it can drift from the version the plugin UI
   expects. (b) is the smallest change, but a re-install still needs a manual
   build. Recommendation: (a), pinned to the same release the plugin runs.
2. Report upstream to omgato so its installer binds the units to
   `graphical-session.target`? Recommendation: yes, as a separate issue on
   their repo once the fix is proven here.
