---
status: draft
issue: 3237
intent: intent/2026-11-26-3237-hyprimate-smoke.md
---

# Spec: hyprimate window animations, Liquid by default, on p620 and razer

## Design

1. **Flake input, following nixarchy's Hyprland.** `flake.nix` gains

   ```nix
   hyprimate = {
     url = "github:JustinBacher/hyprimate/9e667f9…";   # full rev, bumped deliberately
     inputs.hyprland.follows = "nixarchy/hyprland";
   };
   ```

   Upstream's flake builds the plugin; its `nixpkgs` follows `hyprland/nixpkgs`, so the build uses the compositor's
   nixpkgs. Tested 2026-11-26: with this override the Hyprland store path equals the running one on p620 and razer
   (`1i0bfzz…-hyprland-0.57.0+date=2026-11-04_64bde62`, both seen in `pgrep -a Hyprland`) and the build, including
   upstream's post-link symbol check against `${hyprland}/bin/.Hyprland-wrapped`, passes unpatched. A
   `nix flake update nixarchy` moves Hyprland and the plugin together; a plugin that stops building fails the host
   build (owner decision 3). At load time the plugin compares its build hash with the running compositor's and refuses
   to initialise on a mismatch (upstream `src/main.cpp:24`).

2. **Module `modules/desktop/hyprimate.nix`**, the repo's module shape, everything under `mkIf cfg.enable`:
   - `options.features.hyprimate.enable = mkEnableOption …` (default off).
   - `home-manager.users.olafkfreund.home.file.".config/hypr/hyprimate.lua"` (`force = true`), with the plugin's store
     path interpolated (`${pkg}/lib/hyprimate.so`, `pkg = inputs.hyprimate.packages.${pkgs.stdenv.hostPlatform.system}.default`).
     No `environment.systemPackages` entry is needed.

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
     local ok, err = pcall(hl.plugin.load, "@so@")
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

   `window.options.liquid.duration` is the shared value for opening and closing (upstream README); per-animation
   `open/close.options` are left unset so it covers both.

3. **Loading it.** Omarchy ignores the user `hyprland.lua`; `autostart.lua` is loaded and is already written by
   `hosts/common/nixos/omarchy-layouts.nix`. Add a block there in the existing `hypr.repo-keys` form
   (`package.searchpath` then `pcall(require, …)`, notify on error): with the flag off the file is absent and nothing
   runs; with it on, an error is shown, not swallowed.

4. **Hosts.** Import the module and set `features.hyprimate.enable = true;` in `hosts/p620/nixos/nixarchy.nix` and
   `hosts/razer/nixos/nixarchy.nix`. p510 neither imports nor enables it.

### Why this is safe across switches and reloads

The guard is "already registered", not "same path". Checked live on p620: `hl.get_config("plugin.hyprimate.window.style")`
is non-nil once the plugin is loaded and nil for an unknown plugin. So a config reload in a running session never calls
`hl.plugin.load` again, whatever store path the drop-in now names; the new build loads at the next login. On p620's
first deploy the hand-loaded test copy is already registered, so it is not doubled. If Hyprland and the plugin were
bumped together and the compositor still runs the old Hyprland, a load can only happen when nothing is registered,
and the plugin's hash check refuses the mismatch. Omarchy's titlebars code (`workspace-modes.lua`) loads and then
configures in the same Lua chunk, which shows `hl.plugin.load` registers synchronously; the `registered()` check after
the load turns any exception into a visible notification.

## Alternatives rejected

- **hyprpm:** imperative, outside Nix, not reproducible.
- **Upstream's flake as-is:** pins Hyprland v0.57.2, not our 64bde62; ABI mismatch.
- **Local `pkgs/hyprimate` via `mkHyprlandPlugin`:** duplicates upstream's recipe (sprites, symbol check).
- **Fixed `/run/current-system/sw/lib` path with "Cannot load a plugin twice!" as the guard:** depends on how Hyprland
  compares a retargeted symlink, and does not cover a hand-loaded copy at another path.
- **`looknfeel.lua` as the hook:** not managed by this repo; `autostart.lua` already is.

## Risks

- **razer's hybrid GPU** is untested: build razer, deploy, the owner logs in; rollback is the flag or the previous
  generation.
- **Crash at login** ends the session: boot the previous generation from the boot menu, or rebuild from a TTY.
- **Hyprland bump breaks the build:** blocks that upgrade on both hosts (accepted).
- **A future Hyprland drops `decoration.wobble`:** its own `pcall`, so plugin settings still apply.

## Verification

- `just check-syntax`; `just validate`.
- `nix eval`: `features.hyprimate.enable` is true on p620 and razer; on p510 `config.features ? hyprimate` is false
  and `home-manager.users.olafkfreund.home.file` has no `.config/hypr/hyprimate.lua`.
- `just test-host p620` and a razer build (on p620) succeed.
- On p620 before re-login: `hyprctl reload` leaves exactly one `hyprimate` in `hyprctl -j plugin list`, and
  `plugin:hyprimate:window:options:liquid:duration` reads `float: 200.000000`.
- After re-login on each host: `hyprimate` listed once; `window:style` is `liquid`; duration `200`;
  `decoration:wobble:enabled` false; no hyprimate notification; the owner opens, closes and moves a window.
