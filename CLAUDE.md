# CLAUDE.md

## Read first

- `docs/PATTERNS.md` — module, package and security patterns
- `docs/NIXOS-ANTI-PATTERNS.md` — anti-pattern catalogue and the code-review checklist

## Hosts

Three active. `lib/hostTypes.nix` defines two types (`workstation`, `laptop`); each host
imports one plus its own hardware config.

| Host  | Type          | Notes |
| ----- | ------------- | ----- |
| p620  | `workstation` | AMD GPU / ROCm. Set `services.ollama.package = pkgs.ollama-rocm`; `services.ollama.acceleration` was removed from nixpkgs (unrelated to this repo's own `acceleration` attribute in `hosts/common/hardware-profiles/`). |
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

- **No binary cache of our own.** There is no nix-serve/harmonia anywhere in the repo;
  nothing listens on p620:5000. `modules/nix/nix.nix` substitutes from cache.nixos.org and
  nix-community.cachix.org; `flake.nix` adds cuda-maintainers and devenv as flake-level
  `extra-substituters`. Tailscale mesh is used for remote SSH access, not caching.
- **Monitoring was removed** (Prometheus/Grafana/Loki/Alertmanager). Use `journalctl`
  and `systemctl status`.
- **One Wayland session: Nixarchy (Omarchy on Hyprland), plus GNOME.** All three
  hosts offer exactly `omarchy-wayland-session` and `gnome-session`. niri, labwc,
  mango, Noctalia and DankMaterialShell are all gone, and so are their flake
  inputs — anything in the docs or a comment describing `dms-shell.nix`,
  "Niri (DMS)", "Hyprland (DMS)" or `${DESK_SHELL:-noctalia}` is describing a
  tree that no longer exists.
- **`programs.hyprland` is enabled by the nixarchy module, not by us** (#1562).
  It is what supplies the portal, uwsm and the wayland-session basics, so it
  cannot be turned off — but it also registers its own Hyprland login entry.
  `hosts/common/nixos/omarchy-sole-hyprland.nix` forces the module off and
  restates the parts Nixarchy needs, so only Omarchy's session is offered. Read
  that file before touching anything Hyprland-adjacent: there is no option to
  exclude one session, and the two obvious workarounds both fail (a filtered
  `mkForce` on `sessionPackages` reads the value it defines; a session-less
  repackage is rejected by the option's type, which demands
  `providedSessions != [ ]`).
- **The Omarchy theme is the source of truth for colours** (#1562).
  `omarchy theme set X` retints Omarchy's own 24 files at once and a
  `theme-set.d` hook writes X into `nixarchy-theme.nix` at the flake root;
  `modules/desktop/stylix-theme.nix` maps that theme's `colors.toml` onto base16
  and feeds Stylix. Everything Omarchy cannot reach at runtime — Plymouth, GRUB,
  the console, GTK, Qt, fonts, the home-manager targets — follows **at the next
  rebuild**, not instantly. Two consequences: switching a theme leaves the tree
  dirty and `nhs` refuses a dirty tree (same as `nixarchy-apply` with
  `apps.nix`), and p510 follows the same palette because `inputs.nixarchy` is
  flake-wide. Reach the package through `inputs.nixarchy`, never
  `config.programs.nixarchy.package` — nixarchy consumes Stylix, so that closes
  the module fixpoint and evaluation dies with infinite recursion.
- **p510 carries the Omarchy session too** (#1562), with `displayManager = false`
  (the module turns SDDM on by default and would swap out the GDM serving RDP),
  `defaultSession = "gnome"` (adding Omarchy flipped autologin from gnome to
  omarchy on a headless box) and `preinstalls = false` (4 GiB of desktop
  software, `cef-binary` alone 1.9 GiB). It is a selectable entry only —
  `gnome-remote-desktop` serves GNOME, not Hyprland.
- DEX5550 is offline; Samsung and HP are decommissioned.
- MicroVMs are per-host files (`hosts/p510/microvm.nix`), not a shared module.
