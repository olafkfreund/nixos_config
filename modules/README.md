# NixOS Modules

Reusable NixOS modules consumed by host configurations. Imports are
explicit — there is no auto-discovery or `default.nix` re-export. The
host template (`hosts/templates/desktop.nix`) imports the top-level
category modules (`core.nix`, `desktop.nix`, `development.nix`,
`virtualization.nix`, `performance.nix`, `email.nix`, `cloud.nix`,
`programs.nix`); per-host configs add the rest as needed.

## Top-Level Aggregators

- `core.nix` — Baseline system services, networking, users.
- `desktop.nix` — Desktop environments and session.
- `development.nix` — Language toolchains and editors.
- `virtualization.nix` — VM, container, libvirt wiring.
- `performance.nix` — Tuning knobs.
- `email.nix` — Mail clients and SMTP relays.
- `cloud.nix` — Cloud CLIs (consolidated from per-provider wrappers).
- `programs.nix` — Miscellaneous programs.

## Category Subdirectories

- `ai/` — AI tooling (Ollama, providers).
- `cloud/` — Cloud provider packages (single `packages.nix` after the
  wrapper consolidation).
- `common/` — Cross-cutting defaults (e.g. `ai-defaults.nix`).
- `containers/` — Container runtimes (Docker, Podman).
- `desktop/` — Desktop environments and the unified
  `desktop.displayManager` module.
- `development/` — Language toolchains, editors, language servers.
- `email/`, `office/`, `obsidian/`, `spell/`, `fonts/`, `funny/` —
  User-facing application bundles.
- `helpers/` — Internal helper functions (entry: `helpers/default.nix`).
- `installer/` — Live ISO support modules.
- `microvms/` — microvm.nix guest definitions.
- `networking/` — Network stack and Tailscale wiring.
- `nix/` — Nix daemon and binary cache configuration.
- `nix-index/` — `nix-index-database` integration.
- `overlays/` — Module-side overlay registration.
- `packages/` — Curated package sets.
- `pkgs/` — Custom package derivations.
- `programs/` — Per-program modules (terminals, browsers, utilities).
- `scrcpy/`, `webcam/`, `windows/`, `scripts/` — Discrete utilities.
- `secrets/` — agenix-managed secret declarations
  (`api-keys.nix`, etc.).
- `security/` — Security modules (`secrets.nix` wrapper, hardening).
- `services/` — Long-running services (one file per service).
- `storage/` — Filesystem and storage configuration.
- `system/` — System-level concerns (logging, etc.).
- `system-utils/` — System utility bundles.
- `virt/` — libvirt, incus, qemu helpers.

## Templates

- `TEMPLATE.nix` — Skeleton for a new feature module.
- `SYSTEMD_SERVICE_TEMPLATE.nix` — Skeleton for a hardened systemd
  service module.

## Conventions

- One service per file under `services/`.
- Module options live under `features.<name>` or
  `services.<name>` and gate the actual configuration with `mkIf cfg.enable`.
- Hosts compose features through flags rather than inlining
  `services.* = { ... }` blocks. See `docs/PATTERNS.md`.
- Systemd units must use `DynamicUser`, `ProtectSystem = "strict"`,
  `NoNewPrivileges`, and the rest of the hardening checklist in
  `docs/NIXOS-ANTI-PATTERNS.md`.
