# AGENTS.md — shared agent guide (Claude Code, Antigravity, et al.)

> Tool-neutral context for any AI coding agent working in this repo.
> Claude Code reads this alongside `CLAUDE.md`; Antigravity reads it as its
> primary rules file. Keep it concise — deep detail lives in `docs/` and
> `CLAUDE.md`.

## What this repo is

A multi-host **NixOS infrastructure hub**: flake-based, template-driven, ~141
feature modules, managing 3 active hosts. Home Manager is loaded **as a flake
module** — never run `home-manager switch`; use `nixos-rebuild`.

**Hosts:**

- **p620** — AMD workstation (primary dev; AMD ROCm). Workstation template.
- **razer** — Intel/NVIDIA laptop (mobile dev). Laptop template.
- **p510** — Intel Xeon/NVIDIA media server **and desktop** (Plex, *arr, k3s,
  Sunshine, self-hosted CI runner). Workstation template. **Never build or
  deploy without asking first.**

All three run one Wayland session: **Omarchy on Hyprland** (packaged as
Nixarchy, a flake input), with GNOME as a selectable fallback. niri, labwc,
mango, Noctalia and DankMaterialShell are gone, inputs included; COSMIC is
parked. See `docs/architecture/desktop.md`.

(DEX5550 offline; Samsung and HP decommissioned. Prometheus/Grafana/Loki
removed — use `journalctl`/`systemctl` for system state; `grafana-status` and
friends no longer exist. There is no binary cache of our own — nothing listens
on `p620:5000`.)

## Golden rules

1. **Read the patterns first.** `docs/PATTERNS.md` (do) and
   `docs/NIXOS-ANTI-PATTERNS.md` (don't) are authoritative. Zero-tolerance on
   anti-patterns.
2. **Feature-flag architecture.** New services go in their own
   `modules/**` file behind a feature flag, enabled per-host via
   `features.* = { ... }`. **Never** put `services.foo = {…}` directly in
   `hosts/*/configuration.nix`.
3. **Trust the module system.** No `mkIf cond true` — assign `cond` directly.
4. **Explicit imports only.** No magic auto-discovery.
5. **Secrets at runtime only.** Use agenix `passwordFile`/path references;
   never `builtins.readFile` a secret (it lands in the store).
6. **Service hardening is mandatory.** `DynamicUser`, `ProtectSystem=strict`,
   `NoNewPrivileges`, `ProtectHome` for any new service. The one standing
   exception is `modules/desktop/sunshine.nix`, a systemd *user* service that
   needs the session's Wayland socket, GPU nodes and input devices — the
   exception is argued in the module, not taken silently.
7. **No bare URLs**, minimal `with`, minimal `rec`, no IFD.
8. **Branch, never commit to `main`.** `<type>/<issue#>-description`,
   Conventional Commits with the issue number. No backticks in
   `git commit -m` — double quotes do not stop command substitution.

## Workflow (issue-driven)

Issue → branch (`<type>/<issue#>-desc`) → implement → test → PR
(Conventional Commits, `Closes #N`) → merge → deploy. Don't commit straight to
`main`; don't merge untested.

## Build / test / deploy

```bash
just check-syntax          # fast syntax check
just validate              # full validation
just test-host <host>      # build one host
just quick-test            # parallel build all hosts
just quick-deploy <host>   # deploy only if changed (smart)
just <host>                # deploy a host (p620 | razer | p510)
nhs [host] [scope]         # idiot-proof flake-update + test + commit + deploy
```

Always build-test before deploying. p620 deploys locally; razer/p510 over SSH.
For heavy razer rebuilds, build on p620 (`--build-host olafkfreund@p620`) then
`switch-to-configuration switch` locally (root has no SSH key to p620).

## Reasoning protocol (PARR)

Every task follows **Plan → Act → Reflect → Revise → Complete**: plan before
acting, execute one step at a time, verify each checkpoint, never chain
unverified commands, stop on the unexpected.

## Layout

```text
flake.nix              host definitions + inputs/overlays
hosts/<host>/          per-host config (variables.nix, configuration.nix, hw)
hosts/templates/       desktop.nix — one template, workstation | laptop
modules/               feature + service modules (the core; behind flags)
home/                  Home Manager config + role profiles
Users/<user>/          per-user profile compositions
secrets/               agenix-encrypted secrets
docs/PATTERNS.md       best practices (READ FIRST)
docs/NIXOS-ANTI-PATTERNS.md  what to avoid (READ FIRST)
docs/architecture/desktop.md Nixarchy / Omarchy / Hyprland
mkdocs.yml + mkdocs-full.yml  hand-synced nav — change BOTH
```
