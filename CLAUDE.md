# CLAUDE.md

## Read first

- `docs/PATTERNS.md` — module, package and security patterns
- `docs/NIXOS-ANTI-PATTERNS.md` — anti-pattern catalogue and the code-review checklist
- `docs/architecture/desktop.md` — Nixarchy/Omarchy/Hyprland, before touching
  anything Hyprland-adjacent

Docs live in `docs/` and are published to <https://nixos.freundcloud.com/>.
Nav is hand-synced across `mkdocs.yml` (Backstage TechDocs) and
`mkdocs-full.yml` (the published site) — a nav change must land in **both**.

## Hosts

Three active. `lib/hostTypes.nix` defines two types (`workstation`, `laptop`); each host
imports one plus its own hardware config.

| Host  | Type          | Notes |
| ----- | ------------- | ----- |
| p620  | `workstation` | AMD GPU / ROCm. Set `services.ollama.package = pkgs.ollama-rocm`; `services.ollama.acceleration` was removed from nixpkgs (unrelated to this repo's own `acceleration` attribute in `hosts/common/hardware-profiles/`). |
| razer | `laptop`      | Hybrid Intel/NVIDIA (Optimus). Heavy rebuilds: build on p620 via `just deploy-via-p620 razer`. |
| p510  | `workstation` | Media server (Plex, NZBGet, k3s microvms) **and desktop** since 2026-08-31: Omarchy session, Sunshine streaming, self-hosted GitHub Actions runner. **Never build or deploy without asking first.** |

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
6. **Announce before you disrupt a shared host.** Several agents work these
   machines at once. Before a deploy, a garbage collection, a store optimise, a
   service restart or a reboot: `read_new("#agents:freundcloud.org.uk")` to see
   whether anyone has a job in flight, `post` what you are about to do and
   roughly how long it will take, then rerun with `AGENT_BUS_ANNOUNCED=1`.
   A PreToolUse hook enforces this — see `modules/programs/claude-code-managed.nix`.
   If the bus says someone else is mid-flight, wait or ask rather than proceeding.

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

Import the file by path in the host that needs it (`hosts/<host>/configuration.nix`
or a file it imports), then enable it there. There is no `modules/default.nix`
and no auto-discovery — every import is explicit.

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
- **p510 runs the Omarchy session for real** (#1585, superseding the
  arrangement #1562 left behind). It got a monitor, so the three settings that
  held Omarchy at arm's length were inverted: `displayManager = true` (Omarchy's
  SDDM; GDM is gone), `defaultSession = "omarchy"` and `host.class =
  "workstation"`. Two divergences from p620/razer remain, both deliberate:
  `preinstalls = false` (4 GiB of desktop software, `cef-binary` alone 1.9 GiB;
  `/` would go 50.5 → 57.6 GiB) and **autologin stays on** — Sunshine is a
  systemd *user* service that only exists inside a live graphical session, so on
  a host that reboots unattended the alternative is a greeter nobody is there to
  answer. razer keeps autologin off because PRIME-sync Optimus misbehaves with a
  greeter respawn; p510 is pure NVIDIA without PRIME.
  `gnome-remote-desktop` can still serve GNOME over RDP but cannot serve
  Hyprland — that is what Sunshine replaced.
- **Sunshine** (`modules/desktop/sunshine.nix`, `features.sunshine`, p510 only)
  is the standing exception to the DynamicUser/ProtectHome rule below: it needs
  the session's Wayland socket, GPU nodes and input devices. Four traps, in the
  order you hit them: it starts only with a graphical session; a DPMS-off output
  streams solid black with a clean log (`wakeDisplay = true`, and the dispatcher
  is Lua — `hl.dsp.dpms({ action = "enable" })`); `webOrigins` must include the
  port or the web UI refuses every POST with a CSRF error; and setting *any*
  option puts the config in the Nix store, making the web UI's Configuration tab
  read-only. See `docs/applications/sunshine.md`.
- **A GitHub Actions runner lives on p510** (`hosts/p510/nixos/github-runner.nix`,
  `p510-nixarchy`) for nixarchy's KVM/ISO checks. `TMPDIR` points at `/home`
  (CMR, 125 MB/s), never `/mnt/img_pool` — that is an SMR disk at ~9.5 MB/s and
  a 16 GB VM install hangs there rather than failing cleanly. Nothing targets
  the runner yet; nixarchy's workflows are still `runs-on: ubuntu-latest`.
- **An NVIDIA driver version bump cannot be applied with `switch`** — the new
  userspace meets the old in-memory module, three `nvidia-*` units fail and the
  activation rolls back. `nhs` detects this and falls back to `boot` mode; the
  reboot is still yours.
- DEX5550 is offline; Samsung and HP are decommissioned.
- MicroVMs are per-host files (`hosts/p510/microvm.nix`, with the guests under
  `hosts/p510/nixos/microvm/`), not a shared module.
