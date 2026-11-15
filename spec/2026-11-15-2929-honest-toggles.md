---
status: draft
issue: 2929
intent: intent/2026-11-15-2929-honest-toggles.md
---

# Spec: make feature toggles control what they claim

## Design

1. **Development modules.** In each of `home/development/{languages,workflow,productivity}.nix` move the existing
   top-level attributes under `config = lib.mkIf (config.features.development.enable && config.features.development.<x>) { ... };`
   (`<x>` = languages / workflow / productivity). The internal `let cfg` constants stay (they are sub-choices, not toggles).
   Preservation: p510 currently gets productivity packages, so `Users/olafkfreund/p510_home.nix` changes
   `productivity = lib.mkForce false` to `true` with a comment saying the old value was never honoured (#2929).
2. **Terminals.** `home/desktop/terminals/default.nix` takes `config` and sets
   `cfg.terminals.{foot,kitty,alacritty} = config.{foot,kitty,alacritty}.enable` (wezterm/ghostty keep their own modules).
   Preservation: every host gets all three today, so `Users/olafkfreund/profile.nix` sets `kitty = true` (was
   `mkDefault false`, never honoured) and p510, whose `terminals.enable = mkForce false` skips the bridge, sets
   `foot.enable`, `kitty.enable`, `alacritty.enable = lib.mkForce true` next to its existing `ghostty.enable`.
3. **Dead options.** Delete `options.aiDefaults.profile` and the three host `aiDefaults.profile` assignments
   (keep `aiDefaults.enable`); delete `masterHost` from `modules/services/syncthing.nix` and the three hosts.
4. **Package types.** `packages = mkOption { type = types.listOf types.package; ... }` in the eight
   `modules/development/*.nix` files. No host sets a non-empty list (verified by grep), so evaluation is unchanged.
5. **screens.nix.** `import ../variables.nix { }` in all three `hosts/*/nixos/screens.nix`.

## Alternatives rejected

- Honour the old values (drop obsidian/slack/... from p510, kitty from razer): removes features, which the owner ruled out.
- Delete the toggles instead: they are the documented interface (`Users/olafkfreund/profile.nix`) and now work.

## Risks

- A top-level attribute moved under `config` that is really an option declaration → eval error (none of the three files
  declares options; grep shows no `options`). Caught by building all hosts.
- `config.features.development` not defined for some HM user: only `olafkfreund` exists (`Users/`).

## Verification

`snap.sh` before/after: per host `system.path` and `home.path` drvPaths, system and HM package names, system and user
units, `/etc` and HM file names, and `nix store diff-closures` of the built toplevels. Expected: all identical except
the toplevel itself. Plus `just check-syntax`, CI `check-configurations`, `@codex review`.
