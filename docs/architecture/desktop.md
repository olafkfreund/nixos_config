# Desktop (Nixarchy / Omarchy on Hyprland)

Last Updated: 2026-09-01

## The problem

This fleet went through five Wayland compositors — niri, labwc, mango, Hyprland
and COSMIC — plus two shells (Noctalia, DankMaterialShell) and three greeters.
Every one of them needed its own portal wiring, its own theme plumbing and its
own session entry, and each combination broke in a different way. Screen sharing
in particular fails silently whenever `XDG_CURRENT_DESKTOP` disagrees with the
portal backend actually installed.

## The solution

**One Wayland session, on every host: Omarchy on Hyprland**, packaged for NixOS
as [Nixarchy](https://github.com/olafkfreund/nixarchy) and consumed as a flake
input. GNOME stays installed and selectable as a fallback. Everything else is
gone, including the flake inputs.

| Host | Sessions offered | Greeter | Default session |
| --- | --- | --- | --- |
| p620 | `omarchy`, `gnome` | SDDM (Omarchy's) | `omarchy` |
| razer | `omarchy`, `gnome` | SDDM (Omarchy's) | `omarchy` |
| p510 | `omarchy`, `gnome` | SDDM (Omarchy's) | `omarchy` |

Each host wires it up in `hosts/<host>/nixos/nixarchy.nix`, which imports the
Nixarchy module plus a set of shared fragments from `hosts/common/nixos/`:

```nix
imports = [
  inputs.nixarchy.nixosModules.nixarchy
  ../../../nixarchy-apps.nix            # app selection, copied in by nixarchy-apply
  ../../common/nixos/omarchy-input.nix
  ../../common/nixos/omarchy-sddm.nix
  ../../common/nixos/omarchy-workspaces.nix
  ../../common/nixos/omarchy-gog.nix
  ../../common/nixos/omarchy-sole-hyprland.nix
  ../../common/nixos/omarchy-stylix-theme.nix
];

programs.nixarchy.enable = true;
programs.nixarchy.user = "olafkfreund";   # puts the user in the `input` group
programs.nixarchy.displayManager = true;  # Omarchy's SDDM
programs.nixarchy.bootSplash = "force";   # Omarchy's Plymouth theme
```

## Why two files sit at the flake root

A flake cannot read a file outside its own tree. Two Omarchy features therefore
write into the repository itself, and both leave the tree dirty — which matters,
because `nhs` refuses to run on a dirty tree.

| File | Written by | Read by |
| --- | --- | --- |
| `nixarchy-apps.nix` | `nixarchy-apply` (copies `~/.config/nixarchy/apps.nix`) | each host's `nixarchy.nix` |
| `nixarchy-theme.nix` | the `theme-set.d` hook of `omarchy theme set X` | `modules/desktop/stylix-theme.nix` |

!!! warning "Copying is not importing"
    `nixarchy-apply` copies `apps.nix` in and stops there. Importing it is the
    host's job. p620 lacked that import until recently, so app selections made
    in the menu were copied into the flake and built by nobody.

## Only one Hyprland entry at login

`programs.hyprland` is enabled by the Nixarchy module itself, not by this repo.
It supplies the portal, `uwsm` and the wayland-session basics, so it cannot
simply be turned off — but it also registers its own Hyprland login entry,
giving two indistinguishable choices at the greeter.

There is no option to drop a single session.
`hosts/common/nixos/omarchy-sole-hyprland.nix` therefore forces the module off
and restates the parts Nixarchy needs. Read that file before touching anything
Hyprland-adjacent; the two obvious workarounds both fail:

- A filtered `mkForce` on `services.displayManager.sessionPackages` would have
  to read the value it defines — infinite recursion.
- A session-less repackage of the compositor is rejected by the option's own
  type, which asserts `providedSessions != [ ]`.

The `nix eval` diff of the whole system config before and after that file is
empty apart from `sessionPackages`.

## Configuration is Lua, not hyprlang

Hyprland 0.56 config on these hosts is **Lua**. Dispatchers are namespaced under
`hl.dsp.*`, so the string forms found in most documentation silently do nothing:

```bash
hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'   # correct
hyprctl dispatch "dpms on"                              # no-op here
```

User-facing config lives in `~/.config/hypr/` (`hyprland.lua`, `input.lua`,
`monitors.lua`, `bindings.lua`), seeded by Nixarchy with `cp -rn`. Because the
seed does not overwrite, a Home Manager file competing for the same path needs
`force = true`.

## Theming: Omarchy is the source of truth

`omarchy theme set X` retints the 24 files Omarchy owns **immediately** and
writes `X` into `nixarchy-theme.nix`. `modules/desktop/stylix-theme.nix` reads
that name, loads the theme's `colors.toml` out of the Nixarchy package, maps its
named roles onto base16 and hands the result to Stylix.

Everything Omarchy cannot reach at runtime — Plymouth, GRUB, the console, GTK,
Qt, fonts and the Home Manager targets — follows at the **next rebuild**, not
instantly. Because `inputs.nixarchy` is flake-wide, p510 follows the same palette
as the workstations.

!!! danger "Reach the package through `inputs`"
    Use `inputs.nixarchy`, never `config.programs.nixarchy.package`. Nixarchy
    consumes Stylix, so reading its config from the module that *defines*
    `stylix.base16Scheme` closes the module fixpoint and evaluation dies with
    infinite recursion.

See [Theming (Stylix)](theming.md) for the palette itself.

## Screen sharing

`xdg.portal.configPackages` carries `hyprland-portals.conf`, which routes
`ScreenCast` to the Hyprland backend rather than wlr. Losing it is the classic
screen-sharing failure on this fleet, so
`omarchy-sole-hyprland.nix` names it explicitly rather than relying on a default.

If a cast fails with *"unit is masked"*, the cause is almost always a stale
`XDG_CURRENT_DESKTOP` from switching sessions without a clean re-login.

## What was removed

niri, labwc, mango, Noctalia and DankMaterialShell — modules, sessions, greeters
and flake inputs. Any comment or document describing `dms-shell.nix`,
*"Niri (DMS)"*, *"Hyprland (DMS)"* or `${DESK_SHELL:-noctalia}` is describing a
tree that no longer exists.

COSMIC is **parked, not removed**: `desktop.cosmic.enable = false` on every host,
with the module at `modules/desktop/cosmic.nix` and the applets under
`pkgs/cosmic-applets/` kept for an easy re-enable.
