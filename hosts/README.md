# Host Configurations

System configurations for each machine. Every host imports the
parameterised desktop template (`templates/desktop.nix`) via
`lib/hostTypes.nix` and adds host-specific modules on top.

## Active Hosts

- `p620/` — AMD RX 7900 workstation, primary development and AI host.
  Workstation template; full COSMIC/GNOME desktop.
- `p510/` — Intel Xeon system, headless media server (Plex, NZBGet,
  FlareSolverr). Workstation template; no display manager.
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
- Optional host-only modules (e.g. `flaresolverr.nix`).

## Common Layer

`common/` holds fragments shared across hosts:

- `common/nixos/` — `i18n.nix`, `hosts.nix`, `envvar.nix`,
  `host-class.nix`, and the shared fragments:
  - `dev-workstation.nix` — everything p620 and razer configure identically
    (development, virtualization, cloud, MCP, Claude Code, desktop programs).
  - `omarchy-desktop.nix` — the identical `programs.nixarchy` settings, the
    Hyprland portal override and the Omarchy/companion plugins, imported from `hosts/{p620,razer}/nixos/nixarchy.nix`.
- `common/hardware-profiles/` — GPU profiles (`amd-gpu.nix`,
  `nvidia-gpu.nix`).
- `common/shared-variables.nix` — User mappings imported by host `variables.nix`.
- `common/fleet.nix` — Tailnet and LAN addresses of the hosts; plain data, imported
  with `import ../common/fleet.nix`.

Settings all hosts share live in `templates/desktop.nix`, scalars at `mkDefault`
(lists stay plain, so a host adds to them).
What stays per host and why: `docs/architecture/template-system.md`.
