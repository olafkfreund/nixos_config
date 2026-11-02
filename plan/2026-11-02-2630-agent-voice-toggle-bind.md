---
status: draft
issue: 2630
spec: spec/2026-11-02-2630-agent-voice-toggle-bind.md
---

# Plan: keybinding to toggle agent voice

## Decisions carried from the approved spec

- **`agent-say toggle`:** a new subcommand flips the existing runtime switch
  (the `on`/`off` files in `state_dir()`). It prints the new state and shows
  one `notify-send -a "Agent voice" "Agent voice on|off"`. A notification
  failure (`OSError`/`SubprocessError`) is ignored. The `on`, `off` and
  `toggle` subcommands share one `set_switch(state)` helper.
- **Key:** a new option `features.agentVoice.toggleKey` (type str), default
  `"SUPER + SHIFT + ALT + V"`. An empty value disables it. This key is free
  on p620 and razer (`hyprctl binds -j`, 2026-11-02).
- **Binds file:** the bind is a second line in the existing
  `~/.config/hypr/agent-voice-binds.lua`, with the description
  `Agent voice: toggle spoken summaries on/off`. The Super+K search matches
  on this description.
- **When the file is written:** the binds file and the `agentVoiceRequire`
  activation are written when **either** key is non-empty. Each line is
  included only when its own key is non-empty.
- **Hosts:** no host sets the key, so p620 and razer use the default. The
  user-owned `bindings.lua` is not edited, because the `pcall` line is
  already on both hosts.
- **Docs:** `docs/applications/agent-voice.md` gets a short "Turning it on
  and off" section and a `toggleKey` row. The nav is unchanged.
- **Rejected alternatives:**
  - a shell one-liner in the bind (fragile quoting, cannot be tested);
  - a separate binds file (needs edits to `bindings.lua`);
  - setting the key per host (duplicated).

## Steps

1. **`pkgs/agent-say/agent_say.py` (+ test): add `toggle`.**
   - Lines 510–514 (the `elif cmd in ("on", "off")` branch): move the body
     into `def set_switch(state)` next to `gate_switch` (line 84).
     `on`/`off` call `set_switch(cmd)`.
   - Add `elif cmd == "toggle":`. It computes
     `new = "on" if gate_switch(config()) else "off"`, then runs
     `set_switch(new)`, `print(new)`, and the notification in
     `with contextlib.suppress(OSError, subprocess.SubprocessError)`, with
     `timeout=5` and `check=False`.
   - Line 519: add `| toggle` to the usage string.
   - Test in `pkgs/agent-say/test_agent_say.py`, using the existing `dirs`
     and `fake_run` fixtures with `notify-send` stubbed. Start with
     `startEnabled` at its default (`on`). Two `main(["agent-say", "toggle"])`
     calls print `off` then `on`, and `state_dir()/"off"` exists after the
     first call only.

   Verify by:
   `nix build .#nixosConfigurations.p620.pkgs.customPkgs.agent-say -L`
   (its `checkPhase` runs pytest). If that attribute path does not exist,
   find it the way `modules/programs/agent-voice.nix` refers to the package.

   Traps:
   - `contextlib` and `subprocess` are already imported. Check before
     adding imports.
   - The hook path must never write stdout. `toggle` is a CLI path only,
     so printing is fine there.

2. **`modules/programs/agent-voice.nix`: add the `toggleKey` option and the
   bind line.**
   - After `moreKey` (lines 60–64), add `toggleKey`. Its default is
     `"SUPER + SHIFT + ALT + V"` and its description is
     "Hyprland key that toggles spoken summaries on/off. Empty disables it."
   - Line 99: the gate becomes
     `mkIf (cfg.moreKey != "" || cfg.toggleKey != "")`. The text is two
     `optionalString` lines:
     - more, when `cfg.moreKey != ""` (unchanged text);
     - toggle, when `cfg.toggleKey != ""`:
       `o.bind("${cfg.toggleKey}", "Agent voice: toggle spoken summaries on/off", "${cfg.package}/bin/agent-say toggle")`.
   - Line 106: give `agentVoiceRequire` the same `||` gate.

   Verify by: `just test-host p620`, then read the built
   `agent-voice-binds.lua` from the home-manager files in the result and
   check that it has both lines.

   Traps:
   - No `mkIf cond true`.
   - Keep `with lib;` style consistent with the file.
   - Minimal comments (memory).

3. **`docs/applications/agent-voice.md`: document the key.**
   - Line 3: keep `Last Updated: 2026-11-02`.
   - After the options table (line 66), add the row:
     `| toggleKey | SUPER + SHIFT + ALT + V | Key that toggles spoken summaries on/off; "" disables |`.
   - Before `## Commands` (line 94), add `## Turning it on and off`. It
     says:
     - SUPER + SHIFT + ALT + V toggles it and shows a notification;
     - Super+K, then search "voice", finds the key;
     - the CLI equivalents are `agent-say toggle`, `on`, `off` and `status`;
     - the switch survives reboots;
     - `startEnabled = false` starts muted;
     - `enable = false` removes the hooks;
     - check a new key is free with `hyprctl binds -j`.
   - Commands table (line 98): add the row
     `| agent-say toggle | Flip the runtime switch and show the new state |`.

   Verify by: `markdownlint-cli2 docs/applications/agent-voice.md`, or the
   pre-push hook.

   Traps:
   - The pre-push markdownlint checks the whole file (memory).
   - Commands in fenced blocks with a language tag.

4. **Build both hosts.**
   Run `just test-host p620` and `just test-host razer`. Both must succeed.

5. **Deploy p620 and verify live.**
   - Bus `read_new`/`post`, then `AGENT_BUS_ANNOUNCED=1 just p620`. This
     is a branch deploy, so it needs `ALLOW_BRANCH_DEPLOY=1`, or deploy
     after merge.
   - Check there are no failed units.
   - `hyprctl binds -j` lists SUPER+SHIFT+ALT+V (modmask 73, key v) with
     the description. Run `hyprctl reload` if it does not.
   - `agent-say toggle` twice prints `off` then `on`, with two
     notifications.
   - The user confirms the physical key press and the Super+K search.

   Traps:
   - Check nhs is not running first (memory).
   - A stale `HYPRLAND_INSTANCE_SIGNATURE` in herdr shells: use the newest
     entry in `/run/user/1000/hypr`.

6. **Deploy razer and verify.**
   - `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`.
   - `hyprctl binds -j` over ssh lists the bind.
   - `agent-say toggle` twice leaves the state unchanged.

   Traps:
   - razer switch exit 4 from syncthing is cosmetic (memory).
   - Never touch p510.

## Tests

```bash
nix build .#nixosConfigurations.p620.pkgs.customPkgs.agent-say -L
just test-host p620
just test-host razer
```

Expected:

- The agent-say pytest suite passes, including the new toggle test.
- Both hosts build.
- The live checks in steps 5 and 6 pass.

## Review

A fresh Opus agent gets this plan and `git diff origin/main`.

## Rollback

Revert the PR and redeploy. The bind line goes away, and `agent-say on/off`
works as before. If the state was left muted, run `agent-say on`.
