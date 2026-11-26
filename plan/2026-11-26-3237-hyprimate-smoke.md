---
status: approved
issue: 3237
spec: spec/2026-11-26-3237-hyprimate-smoke.md
coders:
  1: coder   # flake input + lock: mechanical, one block
  2: coder   # new module; the Lua is fully specified below, no new logic to invent
  3: coder   # one Lua block in an existing heredoc, copy of the repo-keys pattern
  4: coder   # two one-line import + enable edits
reviewers:
  - codex    # independent read of the diff against this plan
  - agy      # second independent read; agent-team mode is on
---

# Plan: hyprimate window animations, Liquid by default, on p620 and razer

Approved under the owner's fast-track (2026-11-26): "commit and merge and deploy", "Fast-track, cite me".

Approved decisions (from the spec): install upstream hyprimate through its own flake, with `inputs.hyprland.follows =
"nixarchy/hyprland"`, pinned to a full rev. A module `modules/desktop/hyprimate.nix` behind
`features.hyprimate.enable` (default off) writes `~/.config/hypr/hyprimate.lua` for `olafkfreund`; that file disables
wobble (errors ignored on purpose), loads the plugin by its store path only if
`plugin.hyprimate.window.style` is not yet registered, then sets `style = "liquid"` and
`window.options.liquid.duration = 200`, and notifies if the load fails or the plugin is not registered.
`autostart.lua` (written by `hosts/common/nixos/omarchy-layouts.nix`) requires it in the `hypr.repo-keys` form.
Enabled on p620 and razer only.
p510 is never built or deployed.

## Steps

1. `flake.nix` inputs (after the `nixarchy-pkg.follows` block, ~line 132): add

   ```nix
   # hyprimate: window animations as a Hyprland plugin (#3237). Must build against the
   # compositor the session runs, so its Hyprland follows nixarchy's; the plugin rev is pinned.
   hyprimate = {
     url = "github:JustinBacher/hyprimate/9e667f972bf94fd6be33e0158ea3da280e0b134e";
     inputs.hyprland.follows = "nixarchy/hyprland";
   };
   ```

   Then `nix flake lock`. Read the full `git diff flake.lock`: only a new `hyprimate` node (and any new transitive
   nodes it needs) plus `root.inputs.hyprimate`; no existing node's `locked` changes, and the hyprimate node's
   `inputs.hyprland` is `["nixarchy", "hyprland"]`.
   → verify: this prints `true`:

   ```bash
   nix eval --json --impure --expr 'let f = builtins.getFlake (toString ./.); in f.inputs.hyprimate.inputs.hyprland.packages.x86_64-linux.hyprland.outPath == f.inputs.nixarchy.inputs.hyprland.packages.x86_64-linux.hyprland.outPath'
   ```

   Both paths are `/nix/store/1i0bfzzp3zcgqwzhbli22his8l2xdp6c-hyprland-0.57.0+date=2026-11-04_64bde62`.
   Traps: never `nix flake update` (bumps everything); comment explains why, not what.

2. New `modules/desktop/hyprimate.nix`:

   ```nix
   # hyprimate window animations for the Omarchy session (#3237).
   { config, lib, inputs, pkgs, ... }:
   with lib; let
     cfg = config.features.hyprimate;
     pkg = inputs.hyprimate.packages.${pkgs.stdenv.hostPlatform.system}.default;
   in {
     options.features.hyprimate.enable = mkEnableOption "hyprimate window animations (Liquid)";
     config = mkIf cfg.enable {
       home-manager.users.olafkfreund.home.file.".config/hypr/hyprimate.lua" = {
         force = true;
         text = ''<the Lua from the spec, with "@so@" replaced by ${pkg}/lib/hyprimate.so>'';
       };
     };
   }
   ```

   The Lua, verbatim from the spec:

   ```lua
   -- Managed by modules/desktop/hyprimate.nix (#3237).
   local function registered()
     local ok, v = pcall(hl.get_config, "plugin.hyprimate.window.style")
     return ok and v ~= nil
   end
   local function warn(msg)
     hl.exec_cmd("omarchy-notification-send " .. o.shell_quote("hyprimate: " .. msg))
   end

   pcall(hl.config, { decoration = { wobble = { enabled = false } } }) -- upstream: before loading
   if not registered() then
     local ok, err = pcall(hl.plugin.load, "${pkg}/lib/hyprimate.so")
     if not ok then warn("load failed: " .. tostring(err)) end
   end
   if registered() then
     hl.config({ plugin = { hyprimate = { window = {
       style = "liquid",
       options = { liquid = { duration = 200 } },
     } } } })
   else
     warn("not loaded; stock animations")
   end
   ```

   → verify: `nix-instantiate --parse modules/desktop/hyprimate.nix >/dev/null`.
   Traps: in a Nix `''…''` string, Lua `..` and `"` are fine; `${` is Nix interpolation (wanted only for `${pkg}`).
   No `mkIf cond true`. Module shape per AGENTS.md. Minimal comments.

3. `hosts/common/nixos/omarchy-layouts.nix`, inside the `autostart.lua` text, after the `hypr.repo-keys` block
   (~line 31): add

   ```lua
   -- hyprimate window animations (modules/desktop/hyprimate.nix, #3237).
   if package.searchpath("hypr.hyprimate", package.path) then
     local ok, err = pcall(require, "hypr.hyprimate")
     if not ok then
       hl.exec_cmd("omarchy-notification-send " .. o.shell_quote("hypr/hyprimate.lua failed: " .. tostring(err)))
     end
   end
   ```

   Also add "and hyprimate (modules/desktop/hyprimate.nix)" to the header comment line that lists what autostart.lua
   loads (line 9). → verify: `nix-instantiate --parse hosts/common/nixos/omarchy-layouts.nix >/dev/null`.
   Traps: p510 does not import this file today; if it did, the block is a no-op without the drop-in.

4. `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`: add `../../../modules/desktop/hyprimate.nix`
   to `imports` (next to the other entries) and `features.hyprimate.enable = true;` in the body.
   → verify: `nix eval .#nixosConfigurations.p620.config.features.hyprimate.enable` and the razer one print `true`.
   Traps: explicit import only; do not touch hosts/p510.

5. (Claude) Checks and builds: `just check-syntax`; `just validate`; p510 eval checks below; `just test-host p620`;
   razer build on p620 (`nix build .#nixosConfigurations.razer.config.system.build.toplevel --no-link`). Commit,
   push, PR linking intent, spec and plan, `Closes #3237`. Review: fresh Opus agent (plan + diff only) and the
   `reviewers:` above. Merge.

6. (Claude) Deploy after merge: in `~/.config/nixos` (on `main`, check `nhs` is not running), `git pull --ff-only` and
   confirm `git log -1` is the merge commit. Bus: `read_new("#agents:freundcloud.org.uk")`; if someone is mid-flight,
   wait or ask; else `post` "deploying p620 then razer (via p620), ~20 min". Then `just p620`, then
   `just deploy-via-p620 razer` (both with `AGENT_BUS_ANNOUNCED=1`). The same pull, bus and build steps apply to a
   rollback deploy. Then the p620 live reload check; the owner logs
   in again on both hosts for the full check.

## Tests

- `nix eval .#nixosConfigurations.p620.config.features.hyprimate.enable` → `true`; same for razer.
- `nix eval --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.p510.config.features ? hyprimate'`
  → `false`; and

  ```bash
  nix eval --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.p510.config.home-manager.users.olafkfreund.home.file ? ".config/hypr/hyprimate.lua"'
  ```

  → `false`.
- p620 and razer toplevels build.
- After p620 deploy, before re-login: `hyprctl reload`;
  `hyprctl -j plugin list | jq '[.[]|select(.name=="hyprimate")]|length'`
  → `1`; `hyprctl getoption plugin:hyprimate:window:options:liquid:duration` → `float: 200.000000`;
  `hyprctl getoption plugin:hyprimate:window:style` → `str: liquid`.
- After re-login on each host: the same three, plus `hyprctl getoption decoration:wobble:enabled` → `bool: false`, no
  hyprimate notification, and the owner opens, closes and moves a window (razer: on its normal hybrid-GPU setup).

## Rollback

`features.hyprimate.enable = false;` on the host, deploy, log in again. If the session dies at login: pick the
previous generation in the boot menu, or rebuild from a TTY. Full revert: revert the PR's commits.
