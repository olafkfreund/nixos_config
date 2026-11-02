---
status: draft
issue: 2630
intent: intent/2026-11-02-2630-agent-voice-toggle-bind.md
---

# Spec: keybinding to toggle agent voice

## Design

The change has three parts: a `toggle` subcommand in agent-say, a key that
runs it, and a docs update.

### 1. A `toggle` subcommand in agent-say

File: `pkgs/agent-say/agent_say.py`.

- **What it does:** `main()` gains `toggle`. It reads the current state
  through the same `gate_switch(config())` that `status` uses, then calls
  the existing `on`/`off` branch with the opposite value. The `on`/`off`
  file logic becomes a small `set_switch(state)` helper so that `on`,
  `off` and `toggle` share it.
- **Output:** it prints the new state (`on` or `off`).
- **Notification:** it shows one notification:
  `notify-send -a "Agent voice" "Agent voice on"` (or `off`), so a key
  press has visible feedback.
- **Notification failure:** a failed notification is ignored, because the
  switch has already changed. This uses the `OSError`/`SubprocessError`
  guard the file uses elsewhere.
- **Usage text:** the usage string gains `toggle`.
- **Tests:** `pkgs/agent-say/test_agent_say.py` gets one test. It runs
  toggle twice against a temporary `XDG_STATE_HOME`, with `notify-send`
  stubbed, and asserts `off` then `on`. The package's `checkPhase` already
  runs this file.

### 2. The key

File: `modules/programs/agent-voice.nix`.

- **New option:**
  `toggleKey = mkOption { type = types.str; default = "SUPER + SHIFT + ALT + V"; … }`,
  placed next to `moreKey`. Empty disables it.
- **Binds file:** `~/.config/hypr/agent-voice-binds.lua` gains a second
  line:
  `o.bind("${cfg.toggleKey}", "Agent voice: toggle spoken summaries on/off", "${cfg.package}/bin/agent-say toggle")`.
  The description is what the Super+K keybinding search matches, so
  "voice", "agent", "toggle" and "mute" all find it.
- **Gating:** the file is written, and the `agentVoiceRequire` activation
  appends the `pcall(require, "hypr.agent-voice-binds")` line, when
  **either** key is non-empty. Today both are gated on `moreKey` alone.
  Each key's own line is included only when that key is non-empty.
- **Hosts:** none set either key, so p620 and razer both get the default.
  `bindings.lua` already has the `pcall` line on both, so no user file
  changes.

### 3. Docs

File: `docs/applications/agent-voice.md`.

- **Section:** a short "Turning it on and off" section. It covers the key,
  the `agent-say on/off/toggle/status` commands, and `startEnabled`.
- **Options table:** gains a `toggleKey` row, and the `moreKey` row is
  added if it is missing.
- **Nav:** unchanged, since this is an existing page. Bump
  `Last Updated`.

## Alternatives rejected

- **Bind a shell one-liner instead of adding `toggle`:**
  `sh -c 'if [ "$(agent-say status)" = on ]; …'`. The quoting inside a Lua
  string inside a Nix string is fragile, the logic can't be tested, and
  the CLI would lack a toggle.
- **A separate `agent-voice-toggle-binds.lua`:** it needs a new `pcall`
  line in the user-owned `bindings.lua` on both hosts, while the existing
  file is already loaded.
- **Set the key in each host's configuration:** this duplicates the same
  value twice. An option with a default matches `moreKey` and is the
  answer approved in the intent.

## Risks

- **Key conflict:** a future Omarchy or plugin update could take SUPER +
  SHIFT + ALT + V. Hyprland would then fire both binds. Mitigation: the
  option allows a per-host override, and the docs say to check with
  `hyprctl binds -j`.
- **Session reload:** the bind takes effect when Hyprland reloads its
  config, after the deploy's home-manager activation. Hyprland watches the
  config, but if it does not pick it up, `hyprctl reload` is enough.
- **Stale binds file:** `agent-voice-binds.lua` is a store symlink.
  Hyprland reads it at reload, so a stale session keeps the old file until
  it reloads. This is not a correctness risk.
- **No effect on other hosts:** p510 does not enable `features.agentVoice`,
  so nothing there changes.

## Verification

1. `agent-say` `checkPhase` (the new toggle test) passes:
   `just test-host p620` and `just test-host razer` both build.
2. After deploying p620:
   - `hyprctl binds -j` lists SUPER+SHIFT+ALT+V with the description.
   - Pressing it twice flips `agent-say status` off, then on, and shows
     two notifications.
   - Super+K, searching "voice", lists the bind.
3. After `just deploy-via-p620 razer`: `hyprctl binds -j` on razer lists
   the bind, and `agent-say toggle` over ssh flips the state. Run it again
   to restore the state.
4. The docs pass the pre-push markdownlint.
