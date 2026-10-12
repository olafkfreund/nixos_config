---
status: approved
issue: 2258
author: olafkfreund
---

# Intent: Meeting Mode plugin on p620 and razer

## Problem

During a call on p620 or razer, the desktop does not get out of the way:
notification pop-ups show on a shared screen, the idle lock can blank the
screen while you listen, night light tints the camera picture, and Oma
(`omarchy-voice.service`, running on both hosts) keeps its wake word on the
microphone, so it can hear the meeting and answer it.

[olafkfreund/nixarchy-meeting-mode](https://github.com/olafkfreund/nixarchy-meeting-mode)
(merged 2026-10-12) fixes this: it notices a call app using the microphone and
silences notifications, keeps the screen awake, turns night light off and stops
the voice service, then puts back only what it changed. Neither host has it:
nothing in this repo references it.

## Proposed outcome

- On p620 and razer, starting a Meet/Zoom/Teams call turns meeting mode on
  after 3 s; hanging up puts everything back 15 s later, voice included.
- This repo takes the plugin as a flake input, so `nhs` bumps it.
- Adding the bar indicator stays a one-time manual
  `omarchy plugin enable nixarchy.meeting-mode --section center`, as for the
  other nixarchy plugins.

## Affected users and systems

- `flake.nix` (new input), a new `hosts/common/nixos/omarchy-meeting-mode.nix`,
  and imports in `hosts/{p620,razer}/nixos/nixarchy.nix`. Not p510.
- User olafkfreund's Omarchy shell; `omarchy-voice.service` stops during calls.
- Not `hosts/common/nixos/omarchy-meet-binds.nix`: that is the `meet`
  recording keybinding, unrelated.

## Constraints

- Declarative only, through `programs.nixarchy.plugins`, the same shape as
  `omarchy-pixelbuds.nix` (#2195). Nothing imperative in `~/.config/omarchy/plugins`.
- Must evaluate and build on both hosts before merge.

## Open questions

Resolved at approval (2026-10-12): the proposed answer to each stands —
1 pixelbuds-style wiring for olafkfreund, 2 keep voice pausing on.

1. **Wiring:** copy the pixelbuds file (set `programs.nixarchy.plugins` for
   olafkfreund via the input's `packages.default`), or use the plugin's own
   `nixosModules.default` (`programs.nixarchy.meetingMode.enable`), which adds
   it for every Home Manager user through `sharedModules`? I propose the
   pixelbuds copy: one user, same as every other plugin here.
2. **Pausing voice:** on by default. Oma is stopped for the whole call and
   needs its start-up time after. Keep the default? I propose yes.
