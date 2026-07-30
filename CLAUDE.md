# CLAUDE.md

## Read first

- `docs/PATTERNS.md` — module, package and security patterns
- `docs/NIXOS-ANTI-PATTERNS.md` — anti-pattern catalogue and the code-review checklist

## Hosts

Three active. `lib/hostTypes.nix` defines two types (`workstation`, `laptop`); each host
imports one plus its own hardware config.

| Host  | Type          | Notes |
| ----- | ------------- | ----- |
| p620  | `workstation` | AMD GPU / ROCm. Set `services.ollama.package = pkgs.ollama-rocm`; `services.ollama.acceleration` was removed from nixpkgs (unrelated to this repo's own `acceleration` attribute in `hosts/common/hardware-profiles/`). Serves the binary cache. |
| razer | `laptop`      | Hybrid Intel/NVIDIA (Optimus). Heavy rebuilds: build on p620 via `just deploy-via-p620 razer`. |
| p510  | `workstation` | Headless media server (Plex, NZBGet, k3s microvms). **Never build or deploy without asking first.** |

Home Manager profiles live in `home/profiles/{developer,server-admin}`. Home Manager is a
**flake module** — never run `home-manager switch`.

## Non-negotiable

1. **Services belong in `modules/`**, never inline in `hosts/*/configuration.nix`. Enable
   them through `features.<name>.enable` in the host.
2. **Every service** gets `DynamicUser = true`, `ProtectSystem = "strict"`,
   `NoNewPrivileges = true`, `ProtectHome = true`.
3. **Secrets load at runtime only** — `passwordFile` / agenix paths. Never
   `builtins.readFile` a secret; that puts it in the Nix store.
4. **No `mkIf cond true`** — assign the boolean directly.
5. **Explicit imports only** — no `readDir` auto-discovery.

## Module shape

```nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.myservice;
in {
  options.features.myservice.enable = mkEnableOption "MyService";
  config = mkIf cfg.enable { services.myservice.enable = true; };
}
```

Add the file to `modules/default.nix`, then enable it in the host.

## Commands

`just --list` covers everything. The non-obvious ones:

- `nhs [HOST] [SCOPE]` (or `just update-commit-deploy`) — flake update → test build →
  commit + push → switch, atomically, local or remote. Refuses a dirty tree.
  See `docs/UPDATE-DEPLOY.md`.
- `just quick-deploy HOST` — deploys only if the configuration actually changed.
- `just test-host HOST` and `just validate` before any deploy.
- `./scripts/manage-secrets.sh` — create/edit/rekey agenix secrets.

## Adding a user

Add the name to `hostUsers` in `hosts/<host>/variables.nix`, create `Users/<name>/` with
the host home files, add the SSH key to `secrets.nix`, then
`./scripts/manage-secrets.sh create user-password-<name>`.

## Git

Branch `<type>/<issue>-<description>`. Conventional Commits with the issue number:
`feat(monitoring): add X (#123)`. Never commit to main — branch, PR, link the issue.

## Infrastructure notes

Things the code no longer shows, so they are easy to get wrong:

- Binary cache at `http://p620:5000`; Tailscale mesh for remote access.
- **Monitoring was removed** (Prometheus/Grafana/Loki/Alertmanager). Use `journalctl`
  and `systemctl status`.
- **Hyprland was removed.** The desktop is niri with noctalia/DMS.
- DEX5550 is offline; Samsung and HP are decommissioned.
- MicroVMs are per-host files (`hosts/p510/microvm.nix`), not a shared module.
