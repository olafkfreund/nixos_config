---
status: approved
issue: 2630
author: olafkfreund
---

# Intent: keybinding to toggle agent voice

## Problem

Agent voice (`agent-say`, #2596) speaks a summary whenever a Claude Code,
Codex or agy turn finishes. The only way to mute or unmute it is to type
`agent-say off` or `agent-say on` in a terminal. When a call or a meeting
starts, that is too slow, and the switch can't be found from the Super+K
keybinding search because no key is bound to it.

## Proposed outcome

- **One key toggles it:** a single key press mutes agent voice, and the
  next press unmutes it.
- **Visible state:** each press shows a notification with the new state
  (on or off), because the state is otherwise invisible.
- **Searchable:** searching "voice" in the Super+K keybinding menu lists
  the key with a clear description.
- **Both hosts:** works the same on p620 and razer.
- **Documented:** `docs/applications/agent-voice.md` covers the key next
  to the existing `agent-say on/off/status` commands.

## Affected users and systems

- Hosts: p620 and razer, the two hosts with `features.agentVoice` enabled.
  p510 is not affected.
- Code: `modules/programs/agent-voice.nix`, which already writes
  `~/.config/hypr/agent-voice-binds.lua` (the "tell me more" key,
  SUPER+ALT+I), and `pkgs/agent-say`.
- Docs: `docs/applications/agent-voice.md`.

## Constraints

- **Free key on both hosts:** SUPER + SHIFT + ALT + V is free on p620 and
  razer (checked live with `hyprctl binds -j` on 2026-11-02).
- **Existing mechanism:** the existing `agent-voice-binds.lua` is the place
  for the bind, and `bindings.lua` already loads it with `pcall` on both
  hosts. No new edits to the user-owned `bindings.lua`.
- **Same runtime switch:** the key uses the existing `on`/`off` state
  files, so the key and the CLI always agree.
- **Deploy announcement:** deploys go through the agent bus announcement.
  razer is built on p620 (`just deploy-via-p620 razer`). p510 is not
  touched.

## Open questions

- Is SUPER + SHIFT + ALT + V acceptable, or is another key preferred?
- The key is set per host through a module option, with the same default
  on both hosts. Is that fine, or should it be hard-coded?
