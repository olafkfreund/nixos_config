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
   `productivity = lib.mkForce false` to `lib.mkForce true` (p510 imports both the developer
   and server-admin profiles, which set it `true` and `false`; plain `true` would conflict) with a comment saying the old value was never honoured (#2929).
2. **Terminals.** `home/desktop/terminals/default.nix` takes `config` and sets
   `cfg.terminals.{foot,kitty,alacritty} = config.{foot,kitty,alacritty}.enable` (wezterm/ghostty keep their own modules).
   Preservation: every host gets all three today, so `Users/olafkfreund/profile.nix` sets `kitty = true` (was
   `mkDefault false`, never honoured) and p510, whose `terminals.enable = mkForce false` skips the bridge, sets
   `foot.enable`, `kitty.enable`, `alacritty.enable = lib.mkForce true` next to its existing `ghostty.enable`.
   The terminal MIME default (`xdg.mimeApps`, :338-358) is set only when at least one of the three is enabled,
   instead of falling back to `foot.desktop`; every host keeps today's value.
3. **Dead options.** Delete `options.aiDefaults.profile` and the three host `aiDefaults.profile` assignments
   (keep `aiDefaults.enable`; drop the now-unused `mkOption` and `types` from its `inherit` so `deadnix` passes; fix
   the host comments that describe profiles); delete `features.syncthing.masterHost` from `modules/services/syncthing.nix` and the three hosts.
4. **Package types.** (`<lang>.development.packages`, and `modules.development.python.packages`) `packages = mkOption { type = types.listOf types.package; ... }` in the eight
   `modules/development/*.nix` files. No host sets a non-empty list (verified by grep), so evaluation is unchanged.
5. **Notification scripts.** `modules/development/claude-hooks.nix:66` installs both scripts when either flag is
   true; install `claude-notify-permissions` only with `enablePermissionNotifications` and `claude-notify-ready` only
   with `enableReadyNotifications`. Both default `true`, so hosts keep both.
6. **screens.nix.** `import ../variables.nix { }` in all three `hosts/*/nixos/screens.nix`.

## Alternatives rejected

- Honour the old values (drop obsidian/slack/... from p510, kitty from razer): removes features, which the owner ruled out.
- Delete the toggles instead: they are the documented interface (`Users/olafkfreund/profile.nix`) and now work.

## Risks

- A top-level attribute moved under `config` that is really an option declaration → eval error (none of the three files
  declares options; grep shows no `options`). Caught by building all hosts.
- `config.features.development` not defined for some HM user: only `olafkfreund` exists (`Users/`).

## Verification

New tracked `scripts/config-snapshot.sh`: evaluates each host's toplevel with `system.configurationRevision` pinned
to a constant (so commits that configure the same system give the same `.drv`), builds it on p620, and records
package, unit, `/etc` and HM file names. Baseline = `main` @ `cec62a474`. Expected: p620 and razer `IDENTICAL`; p510 changes only by `claude-desktop` in HM packages (already in its system
packages).
Negative checks (the toggles now work): with `extendModules` setting each fixed toggle off, the package or file
disappears (productivity → obsidian, kitty → kitty, `enablePermissionNotifications` → `claude-notify-permissions`). Plus `just check-syntax`, CI `check-configurations`, `@codex review`.
