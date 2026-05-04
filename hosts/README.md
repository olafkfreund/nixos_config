# Host Configurations

System configurations for each machine. Every host imports the
parameterised desktop template (`templates/desktop.nix`) via
`lib/hostTypes.nix` and adds host-specific modules on top.

## Active Hosts

- `p620/` — AMD RX 7900 workstation, primary development and AI host.
  Workstation template; full COSMIC/GNOME desktop.
- `p510/` — Intel Xeon system, headless media server (Plex, NZBGet,
  FlareSolverr). Workstation template; no display manager. MicroVM
  guest config lives in `p510/microvm.nix`.
- `razer/` — Intel + NVIDIA laptop. Laptop template; lanzaboote Secure
  Boot with shim+MOK.

## Templates

There is a single parameterised template:

- `templates/desktop.nix` — accepts `profile = "workstation" | "laptop"`.
  Adds thermald and `cpuFreqGovernor = "powersave"` for the laptop
  profile. Surfaced through `lib/hostTypes.nix` as
  `hostTypes.workstation` and `hostTypes.laptop`. The previous
  `server`, `hybrid`, and `base` templates have been removed; headless
  hosts use the workstation template with `host.class = "workstation"`
  and no display manager.

## Host Directory Structure

Each host typically contains:

- `configuration.nix` — Top-level host config; imports the template
  plus host-specific modules.
- `variables.nix` — Hostname, primary user, feature toggles.
- `nixos/` — Host-local NixOS fragments:
  - `hardware-configuration.nix` — Generated hardware config.
  - `boot.nix`, `power.nix`, `cpu.nix`, `memory.nix`, etc.
  - GPU vendor file (`amd.nix`, `nvidia.nix`, ...).
- `themes/stylix.nix` — Host theme wiring (Stylix + base16 + wallpaper).
- Optional host-only modules (e.g. `microvm.nix`, `flaresolverr.nix`).

## Common Layer

`common/` holds fragments shared across hosts:

- `common/nixos/` — `i18n.nix`, `hosts.nix`, `envvar.nix`,
  `host-class.nix`.
- `common/hardware-profiles/` — GPU profiles (`amd-gpu.nix`,
  `nvidia-gpu.nix`, `intel-integrated.nix`).
- `common/shared-variables.nix` — User mappings consumed by `flake.nix`.
