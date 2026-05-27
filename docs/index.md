---
hide:
  - navigation
---

# NixOS Infrastructure Hub

A multi-host NixOS configuration built on flakes, a single parameterised host
template, Home Manager as a flake module, and Stylix-driven theming. This site
documents **every module, package, and host** — and explains the reasoning
behind each architectural choice.

[Get started](getting-started/overview.md){ .md-button .md-button--primary }
[Browse the reference](reference/modules/index.md){ .md-button }
[View on GitHub](https://github.com/olafkfreund/nixos_config){ .md-button }

## The hosts

<div class="grid cards" markdown>

- :material-desktop-tower: **p620 — AMD Workstation**

    ---

    Primary development and AI workloads. Radeon RX 7900 with ROCm, local
    inference, binary cache server.

    [:octicons-arrow-right-24: Details](hosts/p620.md)

- :material-server: **p510 — Media Server**

    ---

    Headless Intel Xeon server. Plex media stack, NVIDIA transcoding,
    k3s MicroVMs.

    [:octicons-arrow-right-24: Details](hosts/p510.md)

- :material-laptop: **razer — Laptop**

    ---

    Mobile development. Hybrid Intel + NVIDIA graphics, Secure Boot via
    lanzaboote, power management.

    [:octicons-arrow-right-24: Details](hosts/razer.md)

</div>

## How it fits together

<div class="grid cards" markdown>

- :material-file-tree: **One host template**

    ---

    A single parameterised `desktop.nix` template selects between
    `workstation` and `laptop` profiles. No per-host import duplication.

    [:octicons-arrow-right-24: Template system](architecture/template-system.md)

- :material-flag: **Feature flags**

    ---

    Modules are imported explicitly and gated by feature flags with
    dependency and conflict validation.

    [:octicons-arrow-right-24: Feature flags](architecture/feature-flags.md)

- :material-palette: **Stylix theming**

    ---

    A single base16 palette drives colours everywhere — terminals, Zellij,
    COSMIC — from `config.lib.stylix.colors`.

    [:octicons-arrow-right-24: Theming](architecture/theming.md)

- :material-key: **agenix secrets**

    ---

    Secrets are age-encrypted, committed safely, and loaded at runtime —
    never read during evaluation.

    [:octicons-arrow-right-24: Secrets](architecture/secrets.md)

</div>

## Build this site

The documentation is built reproducibly with Nix — the same toolchain locally
and in CI:

```bash
nix build .#docs          # -> ./result (static site)
just docs-serve           # live preview at http://127.0.0.1:8000
just docs-check           # strict build (fails on broken links)
```

!!! info "Always in sync"
    The entire [Reference](reference/modules/index.md) section is generated
    from the live Nix source at build time. It mirrors every file under
    `modules/`, `pkgs/`, `hosts/`, `lib/`, and `overlays/`, so it can never
    drift from the configuration.
