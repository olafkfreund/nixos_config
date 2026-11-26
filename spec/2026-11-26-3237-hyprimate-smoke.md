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

   Upstream's own flake builds the plugin; its `nixpkgs` already follows `hyprland/nixpkgs`, so the whole build uses
   the compositor's nixpkgs. Tested 2026-11-26: with this override the Hyprland store path equals the running one
   (`1i0bfzz…-hyprland-0.57.0+date=2026-11-04_64bde62`) and the build, including upstream's post-link symbol check
   against `${hyprland}/bin/.Hyprland-wrapped`, passes unpatched. A `nix flake update nixarchy` moves Hyprland and the
   plugin together; a plugin that stops building fails the host build (owner decision 3).

2. **Module `modules/desktop/hyprimate.nix`**, the repo's module shape:
   - `options.features.hyprimate.enable = mkEnableOption …` (default off, so p510 cannot inherit it).
   - `environment.systemPackages = [ inputs.hyprimate.packages.${system}.default ]`. `/lib` is already in p620's
     `environment.pathsToLink` (evaluated), so the plugin appears at the fixed path
     `/run/current-system/sw/lib/hyprimate.so`.
   - `home-manager.users.olafkfreund.home.file.".config/hypr/hyprimate.lua"` (force) with:

     ```lua
     -- Managed by modules/desktop/hyprimate.nix (#3237).
     pcall(hl.plugin.load, "/run/current-system/sw/lib/hyprimate.so")
     hl.config({
       decoration = { wobble = { enabled = false } },
       plugin = { hyprimate = { window = {
         style = "liquid",
         options = { liquid = { duration = 200 } },
       } } },
     })
     ```

     `window.options.liquid.duration` is the shared value for opening and closing (upstream README: per-animation
     `open/close.options` override it, so one key covers both).

3. **Loading it.** Omarchy ignores the user `hyprland.lua`; `autostart.lua` is loaded and is already written by
   `hosts/common/nixos/omarchy-layouts.nix`. Add one line there, next to the existing `pcall(require, …)` drop-ins:
   `pcall(require, "hypr.hyprimate")`. With the flag off the file does not exist and the `pcall` is a no-op.

4. **Hosts.** Import the module and set `features.hyprimate.enable = true;` in `hosts/p620/nixos/nixarchy.nix` and
   `hosts/razer/nixos/nixarchy.nix`. p510 neither imports nor enables it.

### Why this is safe across switches and reloads

Hyprland refuses a second load of the same path ("Cannot load a plugin twice!", checked live on p620). The drop-in
always names the fixed `/run/current-system/sw/lib/hyprimate.so`, so after a switch, when that symlink points at a
newly built plugin, a config reload re-runs the load, is refused, and the old plugin keeps running. The new one loads
at the next login. `pcall` keeps that refusal from aborting the rest of `autostart.lua`.

## Alternatives rejected

- **hyprpm:** imperative, outside Nix, not reproducible.
- **Upstream's flake as-is:** pins Hyprland v0.57.2, not our 64bde62; ABI mismatch.
- **Local `pkgs/hyprimate` via `mkHyprlandPlugin`** (nixarchy's titlebars pattern): duplicates upstream's build recipe,
  which embeds sprites and a symbol check; the input override needs no recipe of our own.
- **Store path in the Lua file:** a reload after a switch would load the new plugin beside the old one (different
  path, not refused): two copies in one compositor.
- **`looknfeel.lua` as the hook:** not managed by this repo; `autostart.lua` already is.

## Risks

- **razer's hybrid GPU** is untested. Mitigation: build razer, deploy, owner logs in; rollback is the flag or the
  previous generation.
- **Crash at login** ends the session: recover by booting the previous generation or a TTY rebuild.
- **Hyprland bump breaks the build:** blocks that upgrade on both hosts (accepted).
- **`/lib` collision:** another package shipping `lib/hyprimate.so` is implausible; a build would report it.
- **`decoration.wobble`** keys could be rejected by a future Hyprland; the `hl.config` call would then error in the
  drop-in. It is off by default today, so the line can go if it ever errors.

## Verification

- `nix eval` of `features.hyprimate.enable` for p620 (true), razer (true), p510 (false).
- `just test-host p620` and a razer build (via p620) succeed.
- After deploy and re-login on each host: `hyprctl -j plugin list` names `hyprimate`;
  `hyprctl getoption plugin:hyprimate:window:style` is `liquid`;
  `hyprctl getoption plugin:hyprimate:window:options:liquid:duration` is `200`.
- Before re-login on p620: `hyprctl reload` leaves exactly one hyprimate in `hyprctl -j plugin list`.
