# Overview

This repository is a single Nix flake that builds and deploys three machines
from one shared codebase. It favours **explicitness over magic**: modules are
imported by hand, features are toggled with typed flags, and there is no
auto-discovery to reason around.

## Design goals

| Goal | How it is achieved |
| --- | --- |
| **No per-host duplication** | One parameterised template + shared variables; hosts only declare what is genuinely unique. |
| **Reproducibility** | Pinned `flake.lock`, `nixos-unstable`, binary caches, and a reproducible docs build (`nix build .#docs`). |
| **Explicit imports** | The template imports the module tree directly — no `readDir`/auto-import. |
| **Trust the module system** | Direct boolean assignment (`enable = cond`), never `mkIf cond true`. |
| **Security by default** | Services run unprivileged where possible; secrets load at runtime via agenix. |
| **Consistent look** | Stylix applies one base16 palette across the desktop and terminal stack. |

## The three hosts

| Host | Profile | Hardware | Role |
| --- | --- | --- | --- |
| [**p620**](../hosts/p620.md) | workstation | AMD Ryzen + Radeon RX 7900 (ROCm) | Primary development, local AI inference, binary cache |
| [**p510**](../hosts/p510.md) | workstation (headless) | Intel Xeon + NVIDIA | Plex media server, *arr automation, k3s MicroVMs |
| [**razer**](../hosts/razer.md) | laptop | Intel + NVIDIA (Optimus) | Mobile development, Secure Boot |

!!! note "Decommissioned hosts"
    `DEX5550` and `Samsung` have been removed from the configuration. Older
    references in archived docs are stale.

## What every host shares

Regardless of role, all three hosts enable a common baseline:

- **Development** environment (editors, languages, git tooling)
- **Virtualisation** (libvirt; Docker where appropriate)
- **AI** providers — local Ollama plus OpenAI / Anthropic / Gemini
- **Syncthing** for file sync
- **Tailscale** mesh networking (the local firewall is left to Tailscale's
  trust model)
- **agenix** secrets and the **gruvbox-dark** Stylix theme
- User `olafkfreund`, `Europe/London`, `en_GB.UTF-8`

The differences — GPU stack, display layout, which services run — are described
on each host's page.

## Where to go next

- Want to build it? → [Quick Start](quick-start.md)
- Want to understand *why* it is shaped this way? → [Architecture](../architecture/index.md)
- Want the per-file reference? → [Reference](../reference/modules/index.md)
