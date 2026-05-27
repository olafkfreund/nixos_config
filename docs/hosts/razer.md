# razer — Laptop

The portable workstation: a Razer laptop with hybrid graphics, Secure Boot, and
power management. It is the only host on the `laptop` profile.

| | |
| --- | --- |
| **Profile** | `laptop` |
| **GPU** | Intel iGPU + NVIDIA dGPU (Optimus) |
| **Display** | eDP-1, 1920×1080@120 |
| **NFS** | exports `/extdisk` to `192.168.1.*` |
| **Boot** | **Secure Boot** via lanzaboote |
| **Source** | [`hosts/razer/`](https://github.com/olafkfreund/nixos_config/tree/main/hosts/razer) |

## Why this host is shaped the way it is

razer is a mobile machine, so it makes trade-offs the desktops do not: the
**laptop profile** turns on `thermald` and a `powersave` CPU governor, the Intel
iGPU drives the panel to save battery while the NVIDIA dGPU is available on
demand, and the boot chain is locked down with **Secure Boot**. It still carries
the full development environment so it is a first-class dev box on the move.

## What runs here

### Laptop specifics

- **Secure Boot** via **lanzaboote** (`secure-boot.nix`, `shim.nix`).
- **greetd** login manager; **GNOME** desktop.
- **Power management** — `thermald`, `powersave` governor (from the laptop
  profile).
- **OpenRazer** for Razer peripheral support (the `openrazer` user group).
- Wayland-forced environment (`NIXOS_OZONE_WL`, `MOZ_ENABLE_WAYLAND`, …).

### Development & virtualisation

- Full development environment.
- **Virtualisation** via libvirt; Docker is **off** here, with **lxd** and
  **incus** containers instead.
- **Syncthing** enabled.
- **claude-router CLI** and the **PARR protocol** tooling.

### AI & media

- **AI providers** (Ollama local + cloud providers via agenix).
- **Media** tooling enabled.

### Networking

- **Tailscale** mesh; local firewall delegated to Tailscale.
- **NFS** export of `/extdisk`.

## Hardware notes

Under `hosts/razer/nixos/`: NVIDIA/Optimus setup, the laptop tuning
(`laptop.nix`), `greetd.nix`, boot/CPU/memory/power, and the Secure Boot chain
(`secure-boot.nix`, `shim.nix`). See the
[razer manifest](../reference/hosts/razer.md).

!!! warning "Remote builds for heavy rebuilds"
    Large razer rebuilds can be offloaded to p620:
    `nixos-rebuild build --build-host olafkfreund@p620`, then
    `sudo switch-to-configuration switch`. Build and switch are split because
    root has no SSH key for p620.

## Deploy

```bash
just test-host razer
just quick-deploy razer
just razer
```
