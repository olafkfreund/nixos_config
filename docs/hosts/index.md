# Hosts

Three active machines, all built from the same flake and
[host template](../architecture/template-system.md). This page compares them;
each host has its own page with the full picture.

<div class="grid cards" markdown>

- :material-desktop-tower: __[p620](p620.md)__ — AMD Workstation

    ---

    Primary development + local AI inference + binary cache.

- :material-server: __[p510](p510.md)__ — Media Server

    ---

    Headless Plex + *arr automation + k3s MicroVMs.

- :material-laptop: __[razer](razer.md)__ — Laptop

    ---

    Mobile development with Secure Boot.

</div>

## At a glance

| | p620 | p510 | razer |
| --- | --- | --- | --- |
| __Profile__ | workstation | workstation (headless) | laptop |
| __CPU__ | AMD Ryzen | Intel Xeon | Intel mobile |
| __GPU__ | Radeon RX 7900 (ROCm) | NVIDIA (transcode) | Intel + NVIDIA (Optimus) |
| __Role__ | Dev / AI / cache | Media server | Mobile dev |
| __Desktop__ | Yes | Headless (remote GNOME) | Yes (GNOME) |
| __Secure Boot__ | No | No | Yes (lanzaboote) |
| __Display__ | 2× 2560×1440@120 | 1× 4K@30 | eDP 1920×1080@120 |
| __NFS export__ | `/extdisk` | `/mnt/data` | `/extdisk` |

## Shared baseline

Every host enables the same foundation, so only the differences are worth
documenting per host:

- __Development__, __virtualisation__, __AI__ (Ollama + cloud providers),
  __media__ tooling, __Syncthing__
- __Tailscale__ mesh networking (local firewall delegated to Tailscale)
- __agenix__ secrets, __gruvbox-dark__ Stylix theme
- User `olafkfreund`, `Europe/London`, `en_GB.UTF-8`, UK keyboard

## What differs (and why)

| Dimension | p620 | p510 | razer |
| --- | --- | --- | --- |
| __Why it exists__ | Daily driver + GPU compute | Always-on media + services | Portable workstation |
| __Signature services__ | Ollama (ROCm), LiteLLM router, glance, binary cache | Plex, recyclarr, FlareSolverr, audiobook/*arr MCP, k3s | OpenRazer, power mgmt |
| __Boot__ | Standard | Standard | Secure Boot (lanzaboote) |
| __Docker__ | On | On | Off (libvirt + lxd/incus) |

Reference-level per-host file manifests live under
[Host Manifests](../reference/hosts/index.md).
