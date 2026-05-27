# Repository Layout

A tour of the top-level directories. Each one links to the generated
[Reference](../reference/modules/index.md) where relevant.

```text
nixos_config/
├── flake.nix              # All host definitions + dev/CI/docs outputs
├── Justfile               # Task runner: build, test, deploy, docs
├── lib/                   # Flake helpers: features, host types, secrets, validation
├── hosts/                 # Per-host config (thin) + shared template
│   ├── templates/         #   desktop.nix — the single parameterised template
│   ├── common/            #   shared variables + hardware GPU profiles
│   ├── p620/  p510/  razer/
├── modules/               # 200+ feature modules, imported explicitly
│   ├── services/          #   the largest category — daemons & integrations
│   ├── ai/  desktop/  development/  security/  virt/  …
├── home/                  # Home Manager configs + role profiles
│   └── profiles/          #   developer, server-admin, …
├── Users/                 # Per-user composition (olafkfreund)
├── pkgs/                  # ~60 custom/vendored packages
├── overlays/              # Overlays: custom packages + upstream fixes
├── secrets/               # agenix-encrypted .age files (safe to commit)
├── assets/                # Wallpapers, themes, icons, certificates
├── scripts/               # Management & install-helper scripts
├── checks/                # Flake checks (quality gates)
├── docs/                  # This documentation (MkDocs source)
└── docs_gen/              # Reference generator + Nix site build
```

## What lives where

| Directory | Purpose | Reference |
| --- | --- | --- |
| `lib/` | Pure helper functions wired into the flake | [Library Functions](../reference/lib.md) |
| `hosts/` | Thin host configs; the heavy lifting is in the template | [Host Manifests](../reference/hosts/index.md) |
| `modules/` | Reusable, feature-flagged building blocks | [Modules](../reference/modules/index.md) |
| `pkgs/` | Packages not in nixpkgs (or patched) | [Custom Packages](../reference/packages.md) |
| `overlays/` | Inject `pkgs/` + apply fixes to nixpkgs | [Overlays](../reference/overlays.md) |
| `home/` | User-space programs and dotfiles via Home Manager | — |
| `secrets/` | Encrypted secrets + `secrets.nix` access rules | [Secrets](../architecture/secrets.md) |

## Conventions

- **Modules are imported explicitly.** There is no auto-discovery; the import
  list in the template is the single source of truth for what loads.
- **Hosts stay thin.** A host file should mostly be feature flags and the few
  things that are genuinely unique to that machine (display layout, GPU,
  host-specific services).
- **Services belong in `modules/`.** Never write `services.foo = { … }`
  directly in a host file — wrap it in a module with a feature flag so it is
  reusable and testable. See [Feature Flags](../architecture/feature-flags.md).
- **Encrypted secrets are committed; plaintext is not.** `.age` files are safe
  in git; the access rules live in `secrets/secrets.nix`.
