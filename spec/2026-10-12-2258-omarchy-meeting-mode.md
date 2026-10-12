---
status: approved
issue: 2258
intent: intent/2026-10-12-2258-omarchy-meeting-mode.md
---

# Spec: Meeting Mode plugin on p620 and razer

## Design

This repo only. The plugin's flake (`packages.default`, `checks`) is already
merged in `olafkfreund/nixarchy-meeting-mode`. Same shape as #2195 (pixelbuds),
as approved.

1. `flake.nix`: a new input directly after `nixarchy-pixelbuds`:

   ```nix
   # nixarchy-meeting-mode: quiet desktop during calls (DND, stay awake, night
   # light off, omarchy-voice stopped); hosts/common/nixos/omarchy-meeting-mode.nix.
   nixarchy-meeting-mode = {
     url = "github:olafkfreund/nixarchy-meeting-mode";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

   `flake.lock` gains only that node (`nix flake lock`, not `update`).

2. New `hosts/common/nixos/omarchy-meeting-mode.nix`, a copy of
   `omarchy-pixelbuds.nix`:

   ```nix
   home-manager.users.olafkfreund =
     { pkgs, ... }:
     {
       programs.nixarchy.plugins."nixarchy.meeting-mode".src =
         inputs.nixarchy-meeting-mode.packages.${pkgs.stdenv.hostPlatform.system}.default;
     };
   ```

   The header comment says what it does, that it stops `omarchy-voice.service`
   during calls, and the one manual step:
   `omarchy plugin enable nixarchy.meeting-mode --section center`.

3. Import it in `hosts/p620/nixos/nixarchy.nix` and
   `hosts/razer/nixos/nixarchy.nix`, after `omarchy-pixelbuds.nix`.

Settings stay at the plugin's defaults, voice pausing included, as approved.
They live in `shell.json` and are changed from the plugin's settings panel, so
nothing here sets them.

## Alternatives rejected

- **The plugin's `nixosModules.default`**: installs for every Home Manager
  user through `sharedModules`; rejected at intent approval (one user, same as
  every other plugin here).
- **`omarchy plugin add`**: imperative and unpinned; `nhs` would not bump it.
- **A `features.*` flag**: none of the other `omarchy-*.nix` plugin files has
  one; the host import list is the switch.

## Risks

- **Voice during calls**: Oma is stopped while a call app holds the mic and
  needs its start-up time after; on razer its Vulkan env
  (`GGML_VK_VISIBLE_DEVICES=1`) is in the unit, so a restart keeps it. A daemon
  started with `omarchy-voice run` is not paused.
- **False positives**: any browser recording from the mic (e.g. a voice memo
  site) counts as a call. `callApps` in `shell.json` narrows it if it bites.
- **Collision**: none. No `nixarchy.meeting-mode` or upstream
  `io.github.jburchel.meeting-mode` folder exists in `~/.config/omarchy/plugins`
  (checked on p620).
- **Deploy**: a Home Manager switch during a call can start voice early (the
  plugin's README "Limits").

## Verification

- `nix flake check` style eval for both hosts:
  `nix build .#nixosConfigurations.{p620,razer}.config.system.build.toplevel --dry-run`
  evaluates; then a full build of both.
- Both hosts have the plugin:
  `nix eval .#nixosConfigurations.<host>.config.home-manager.users.olafkfreund.programs.nixarchy.plugins --apply builtins.attrNames`
  lists `nixarchy.meeting-mode`. nixarchy validates the manifest while it builds
  (`modules/home.nix` `validatedPlugins`) and links the folder at activation,
  so a full build that succeeds proves the manifest is valid.
- Runtime (manual, after deploy on each host): enable it once, run
  `pw-record -P '{ application.name = "Google Chrome" }' /dev/null` for >3 s →
  `systemctl --user is-active omarchy-voice` says `inactive` and the bar
  indicator lights; Ctrl+C, wait 15 s → `active` again.
