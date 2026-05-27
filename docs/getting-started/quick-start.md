# Quick Start

Everyday commands are wrapped in the `Justfile`. Run `just --list` to see them
all; the essentials are below.

## Clone

```bash
git clone https://github.com/olafkfreund/nixos_config.git ~/.config/nixos
cd ~/.config/nixos
```

## Validate and test

```bash
just check-syntax        # fast Nix syntax check
just validate            # full validation suite
just test-host p620      # build a host without switching
just quick-test          # build all hosts in parallel
```

## Deploy

```bash
just quick-deploy p620   # smart deploy — only if the build changed
just p620                # optimised deploy to a specific host
just deploy-all-parallel # deploy every host at once
```

!!! tip "Routine lock bumps"
    For the idiot-proof *update + commit + deploy* flow, use the `nhs`
    shortcut (or `just update-commit-deploy HOST SCOPE`). It runs
    `nix flake update → test-build → commit + push → switch` atomically and
    refuses to run on a dirty tree. See
    [Update & Deploy](../UPDATE-DEPLOY.md).

## Build the documentation

This very site is a flake output:

```bash
nix build .#docs         # -> ./result (static site)
just docs-serve          # live preview at http://127.0.0.1:8000
just docs-check          # strict build — fails on broken links
```

## Secrets

```bash
./scripts/manage-secrets.sh status          # show secret state
./scripts/manage-secrets.sh create NAME     # create a new secret
./scripts/manage-secrets.sh edit NAME       # edit an existing secret
```

See [Secrets (agenix)](../architecture/secrets.md) for the model.

## A note on Home Manager

Home Manager is loaded as a **flake module**. Do **not** run
`home-manager switch` — user environments are activated automatically by the
system rebuild (`just <host>` / `nixos-rebuild switch`). See
[Home Manager](../architecture/home-manager.md).

## Rollback

NixOS keeps every generation. If a deploy misbehaves:

```bash
sudo nixos-rebuild switch --rollback
```
