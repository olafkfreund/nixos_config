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

## Layouts

New workspaces open in the scrolling layout. The default is set in
`hosts/common/nixos/omarchy-layouts.nix` and loaded by the store's
`hyprland.lua` since nixarchy#1598, after Atmos's `looknfeel` (so it overrides
that default) and before the saved SUPER+L choices, which still win.

| Keys | Scrolling | Master | Monocle |
| --- | --- | --- | --- |
| SUPER+SHIFT+L | to master | to monocle | to scrolling |
| SUPER+[ / SUPER+] | narrower / wider column | smaller / bigger main window | previous / next window |
| SUPER+# (US `\`) | swap column | swap into main window | — |
| SUPER+CTRL+SHIFT+L | horizontal / vertical strip (not kept across a config reload) | — | — |

Master puts the big window on the right at 65%; new windows stack on the left.
SUPER+L still cycles dwindle, scrolling and floating only: on master or monocle
it goes to dwindle, and the bar shows the dwindle square for both.

## Keys

Shared keys are declared as data in `hosts/common/nixos/omarchy-keys.nix`,
imported by p620 and razer. It writes `~/.config/hypr/repo-keys.lua` and
`repo-keys.json`, and `autostart.lua` loads the Lua after `bindings.lua`. Each
declared key runs `hl.unbind` then `o.bind`, so the repo wins on a declared chord.
Keys on other chords that were added by hand keep working. p510 does not import
the module. Chords are written `SUPER+CTRL+ALT+SHIFT+K`: modifiers in that order,
no spaces.

### Declared keys (both hosts)

| Chord | Description |
| --- | --- |
| `SUPER+CTRL+M` | Gmail (freundcloud) |
| `SUPER+CTRL+SHIFT+M` | New email (freundcloud) |
| `SUPER+SHIFT+C` | Calendar (freundcloud) |
| `SUPER+CTRL+J` | AI Kit |
| `SUPER+CTRL+SHIFT+D` | New Google Doc (freundcloud) |
| `SUPER+CTRL+SHIFT+S` | New Google Sheet (freundcloud) |
| `SUPER+CTRL+SHIFT+P` | New Google Slides (freundcloud) |
| `SUPER+SHIFT+S` | Google Maps |
| `SUPER+SHIFT+P` | Google Photos |
| `SUPER+CTRL+SHIFT+G` | Google Messages |
| `SUPER+ALT+SHIFT+G` | WhatsApp |
| `SUPER+E` | Exposé |
| `SUPER+H` | Nixi (nixarchy help) |
| `SUPER+M` | Toggle voice control |
| `SUPER+N` | Minimize window to the dock |
| `SUPER+SHIFT+H` | Herdr sessions menu |
| `SUPER+ALT+A` | GitHub Actions |
| `SUPER+CTRL+ALT+A` | GitHub Actions keybindings |
| `SUPER+ALT+P` | GitLab Pipelines |
| `SUPER+CTRL+ALT+P` | GitLab Pipelines keybindings |
| `SUPER+ALT+B` | Bar settings |
| `SUPER+ALT+Q` | Quick actions |
| `SUPER+ALT+N` | nixarchy packages |
| `SUPER+ALT+E` | Dev environments |
| `SUPER+ALT+D` | Distrobox |
| `SUPER+ALT+O` | Podman |
| `SUPER+SHIFT+K` | OmaFob |

### Per-host keys

| Chord | Description |
| --- | --- |
| `SUPER+CTRL+ALT+G` | Govee lights |

Govee is p620 only. razer gets Exposé, Dev environments, Distrobox and Podman
from the shared list; Govee and Meeting AI stay p620 only.

Unbound on both hosts: `SUPER+SHIFT+E` and `SUPER+ALT+SHIFT+E`.

### External keys

These are bound by other repo modules or plugins. They are declared so the check
sees them and the menu lists them, but `omarchy-keys.nix` does not bind them.

| Chord | Description |
| --- | --- |
| `SUPER+ALT+I` | Agent voice: tell me more |
| `SUPER+ALT+SHIFT+V` | Agent voice: toggle spoken summaries on/off |
| `SUPER+SHIFT+ESCAPE` | ai-mirror: stop agent control |
| `ALT+TAB` | Altscape: next window |
| `ALT+SHIFT+TAB` | Altscape: previous window |
| `SUPER+ALT+SHIFT+W` | Altscape settings |
| `SUPER+SHIFT+V` | New Google Meet (link copied) |
| `SUPER+CTRL+ALT+M` | Meeting record/transcribe/summarize |
| `SUPER+ALT+V` | MicroVMs |
| `SUPER+ALT+H` | Nixi companion: show or hide |
| `SUPER+ALT+SHIFT+S` | Nixi companion: listen |
| `SUPER+ALT+U` | Plugin browser |
| `SUPER+SHIFT+L` | Cycle workspace layout: scrolling, master, monocle |
| `SUPER+CTRL+SHIFT+L` | Layout: flip scrolling between horizontal and vertical |

p620 only (Meeting AI):

| Chord | Description |
| --- | --- |
| `SUPER+ALT+M` | Meeting AI overlay |
| `SUPER+ALT+T` | Meeting AI: start recording |
| `SUPER+ALT+SHIFT+T` | Meeting AI: stop recording |
| `SUPER+ALT+SHIFT+N` | Meeting AI: toggle microphone |
| `SUPER+ALT+Y` | Meeting AI: toggle system audio |
| `SUPER+ALT+SHIFT+P` | Meeting AI: screenshot |

### Keys that are not declared

- Omgato (plugin-owned): `SUPER+CTRL+ALT+L` lights, `SUPER+ALT+R` record area,
  `SUPER+ALT+SHIFT+R` stop.
- The layout keys on `code:` keycodes (SUPER+[, SUPER+] and SUPER+#, in the
  Layouts table) and Altscape's `ALT+Alt_L` and `ALT+Alt_R`. `hyprctl binds`
  doesn't name them as chords, so the check skips them.
- Vimarchy's submap and `ALT+SPACE`, which stay in `bindings.lua`.
- Hyprforge is dormant: its optional file would use `SUPER+ALT+H` and
  `SUPER+ALT+SHIFT+P`, which now belong to Nixi companion and Meeting AI. If it
  returns, one side has to move.

### Changing a key

Edit `shared` or the host's `extra` in `omarchy-keys.nix` or the host's
`nixarchy.nix`, update the row above, and deploy. Hyprland reloads when the
files change. Do not add a declared key to `bindings.lua`: the repo unbinds that
chord first.

### Checking keys

`hypr-keys-check` compares `repo-keys.json` with `hyprctl binds -j` and
`omarchy-menu-keybindings --print`. It fails on a missing key, a wrong
description, a key absent from the menu, a still-bound `unbind` chord and a
chord bound twice. `--keys FILE` reads another declaration and `--docs FILE`
also requires each chord and description to share a line in that file:

```bash
hypr-keys-check --docs docs/architecture/desktop.md
```

Run it inside a live session; `hyprctl` is not useful outside one.

## Theming: Omarchy is the source of truth

`omarchy theme set X` retints the 24 files Omarchy owns **immediately** and
writes `X` into `nixarchy-theme.nix`. `modules/desktop/stylix-theme.nix` reads
that name, loads the theme's `colors.toml` out of the Nixarchy package, maps its
named roles onto base16 and hands the result to Stylix.

Everything Omarchy cannot reach at runtime — Plymouth, GRUB, the console, fonts
and the remaining Home Manager targets — follows at the **next rebuild**, not
instantly. GTK, Qt colours and the icon theme follow a switch **live**: the
Omarchy theme engine (hyprchroma) owns `gtk.css`, the GNOME interface keys and
`kdeglobals` (Issue #2370). Because `inputs.nixarchy` is flake-wide, p510 follows the same palette
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

## Getting a Nixarchy change onto the hosts

The flake follows `github:olafkfreund/nixarchy/edge`, not `main`. `edge` is
republished from `main` by Nixarchy's `omarchy-edge` workflow, daily at 06:07
UTC or when dispatched, and it waits for other Nixarchy CI to go idle first.
A PR merged into Nixarchy `main` is therefore not yet on the hosts, and a lock
bump taken before `edge` is republished silently leaves it out.

1. Check `edge` contains the merge (`0` means it does):

    ```bash
    gh api repos/olafkfreund/nixarchy/compare/<merge-sha>...edge -q .behind_by
    ```

2. Bump and deploy: `nix flake update nixarchy`, then the usual PR and deploy.
3. **Log out and back in.** The session's `OMARCHY_PATH` points at the
   Omarchy tree that was current at login, so menu, bar and other desktop
   changes do not appear after a switch, and `omarchy-restart-shell` does not
   help.

## Checking a host: `nixarchy-verify`

`nixarchy-verify` checks the parts of the desktop only real hardware can
answer: portals, lock, idle, notifications, Bluetooth, KVM, theme, every
menu row, gliff. It prints `✓` pass, `✗` fail and `·` worth a look; the
`·` lines are mostly informational (Stay Awake on, no battery, nothing
running to test).

It needs the graphical session. Over SSH, borrow its environment:

```bash
ssh p510 'set -a; eval "$(systemctl --user show-environment | grep -E "^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|OMARCHY_PATH|DBUS_SESSION_BUS_ADDRESS|PATH)=")"; set +a; nixarchy-verify'
```

Known failure: on p510 (NVIDIA 595) `gliff end to end` fails. The GPU path
cannot import the NVIDIA decode surface and the CPU path scores under gliff's
PSNR floor on a captured frame (omacom/gliff#84, omacom/gliff#85). Nothing on
p510 uses gliff; Sunshine is its remote desktop.

## What was removed

niri, labwc, mango, Noctalia and DankMaterialShell — modules, sessions, greeters
and flake inputs. Any comment or document describing `dms-shell.nix`,
*"Niri (DMS)"*, *"Hyprland (DMS)"* or `${DESK_SHELL:-noctalia}` is describing a
tree that no longer exists.

COSMIC is **parked, not removed**: `desktop.cosmic.enable = false` on every host,
with the module at `modules/desktop/cosmic.nix` and the applets under
`pkgs/cosmic-applets/` kept for an easy re-enable.
