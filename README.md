# NixOS Configuration

Multi-host NixOS configuration using flakes, a single parameterised host
template, Home Manager as a flake module, and Stylix-driven theming.

Last verified: 2026-05-04 against `nixos-unstable` (NixOS 26.05).

## Hosts

| Host  | Class       | Hardware       | Role                              | Template            |
|-------|-------------|----------------|-----------------------------------|---------------------|
| p620  | workstation | AMD RX 7900    | Primary development, AI workloads | desktop/workstation |
| p510  | workstation | Intel Xeon     | Headless media server (Plex)      | desktop/workstation |
| razer | laptop      | Intel + NVIDIA | Mobile development, Secure Boot   | desktop/laptop      |

DEX5550 and Samsung have been removed from the configuration. References
in older docs are stale.

## Architecture

- Single parameterised host template at `hosts/templates/desktop.nix`
  (selects between `workstation` and `laptop` profiles via the
  `profile` argument). Surfaced through `lib/hostTypes.nix` as
  `hostTypes.workstation` / `hostTypes.laptop`. The previous
  `server`/`hybrid`/`base` templates were removed; P510 also uses the
  workstation template (headless via `host.class = "workstation"` and
  no display manager).
- Hardware GPU profiles in `hosts/common/hardware-profiles/` (`amd`,
  `nvidia`, `intel-integrated`).
- Feature flags drive module enablement (see `lib/features.nix`).
- Module tree under `modules/` is imported explicitly by the template;
  there is no auto-discovery.
- Overlays are split by purpose under `overlays/`:
  `default.nix`, `custom-packages.nix`, `cmake-compat.nix`,
  `python-compat.nix`, `upstream-fixes.nix`, `citrix-workspace.nix`.
- Theming is centralised through Stylix (`base16` palette). Dependent
  surfaces — GNOME Terminal, Zellij, COSMIC (full RON palette write,
  30 fields) — derive their colours from
  `config.lib.stylix.colors`. The standalone `nix-colors` input has
  been removed.
- Home Manager is loaded as a flake module from `flake.nix`. Do **not**
  run `home-manager switch` directly; user environments are activated
  by the system rebuild.

## Quick Start

```bash
git clone https://github.com/olafkfreund/nixos_config.git ~/.config/nixos
cd ~/.config/nixos
just validate                 # Configuration validation
just test-host p620           # Build a host without switching
just <host>                   # Build and switch (p620 / p510 / razer)
```

## Routine Update + Deploy

The recommended flow for the common case (bump lock, commit, push,
build, switch) — works for local and remote hosts, refuses to run with
a dirty tree, and never orphans a lock:

```bash
nhs                           # current host, nixpkgs scope (zsh shortcut)
nhs razer                     # remote deploy via SSH (nh --target-host)
nhs p510 all                  # update all flake inputs, deploy p510
nhs razer home-manager        # bump a single input

# Without the alias:
just update-commit-deploy [HOST] [SCOPE]

# Pre-build for a currently offline host (commit + build now, deploy later):
nhsb razer
```

Full reference: [docs/UPDATE-DEPLOY.md](./docs/UPDATE-DEPLOY.md).

## Directory Layout

```text
flake.nix                       Main flake (inputs, outputs, host wiring)
Justfile                        Automation recipes (just --list)
lib/                            Shared functions (hostTypes, features, secrets, live-images)
modules/                        Feature modules (explicit imports only)
overlays/                       Split nixpkgs overlays
hosts/
  templates/desktop.nix         Single parameterised template (workstation | laptop)
  common/                       Shared host fragments + hardware-profiles
  p620/  p510/  razer/          Per-host configurations
home/                           Home Manager modules
  profiles/                     Role-based profiles (developer, server-admin, ...)
Users/<user>/<host>_home.nix    Per-user, per-host Home Manager entry
secrets/                        agenix-encrypted secrets (.age)
checks/                         flake checks (nix flake check)
scripts/                        Operational scripts
docs/                           Documentation
assets/wallpapers/              Centralised wallpapers (consumed by Stylix)
```

## Common Commands

```bash
# Validation
just check-syntax               # Nix syntax pass
just validate-quick             # Fast validation
just validate                   # Full validation
just test-host <host>           # Build a host without switching

# Deployment
just deploy                     # Local switch
just <host>                     # Build + switch a specific host
just quick-deploy <host>        # Deploy only if the closure changed
just update-commit-deploy <host> [scope]   # See docs/UPDATE-DEPLOY.md
nhs [host] [scope]              # zsh shortcut for the above

# Maintenance
just cleanup                    # GC old generations
just update-flake               # nix flake update (no commit)
just secrets                    # Interactive secrets manager
just --list                     # All recipes
```

## Feature Flags

Hosts compose functionality through flags rather than direct service
configuration. Example (from `hosts/p620/configuration.nix`):

```nix
features = {
  development.enable = true;
  desktop.enable = true;
  virtualization = {
    enable = true;
    docker = true;
  };
};
```

Adding a new service: create a module under
`modules/services/<name>.nix` exposing `features.<name>` options, then
import it explicitly from the template or host. Do not place
`services.* = { ... }` blocks directly in
`hosts/*/configuration.nix`.

## Secrets

Encrypted with agenix; decrypted at activation time only.

```bash
just secrets                                    # Interactive manager
./scripts/manage-secrets.sh create <name>
./scripts/manage-secrets.sh edit   <name>
./scripts/manage-secrets.sh rekey
```

Always reference secrets by path, never read them at evaluation time:

```nix
# Correct — runtime load
services.myapp.passwordFile = config.age.secrets.myapp-password.path;

# Wrong — embeds the secret in /nix/store
services.myapp.password = builtins.readFile "/secrets/password";
```

Access control lives in `secrets.nix` (per-host and per-user public
keys).

## Razer: Secure Boot

razer boots via lanzaboote (`v1.0.0`) with `systemd-initrd`. Because
the firmware ships a locked Setup Mode, MOK enrollment is handled by a
shim+MOK module (`modules/razer/...`) that wraps `lzbt` and points
`pkiBundle` at `/var/lib/sbctl` (the sbctl 0.18 default). Kernel is
pinned to `linuxPackages_latest` to dodge the 6.18.24 + NVIDIA boot
regression.

## Live Installer

A bootable installer image is produced for razer:

```bash
nix build .#live-iso-razer
just show-devices                 # Identify the USB target
just flash-live razer /dev/sdX    # Destructive, double-check the device
```

Live images for other hosts have been removed from the flake; the same
builder (`lib/live-images.nix`) can be re-instantiated if needed.

## Theming

- Source of truth: `config.lib.stylix.colors` (base16 scheme).
- `assets/wallpapers/` contains all wallpapers; the active wallpaper is
  selected by the per-host theme module.
- COSMIC: a writer derivation produces the full RON palette (30
  fields) from the base16 scheme; no hardcoded hex values remain.
- GNOME Terminal: palette derived from Stylix base16.
- Zellij: theme derived from Stylix.
- GNOME profile: shared `home/profiles/desktop-user/profile.nix` and
  the `desktop.gnome.profile` module unify the wiring; the
  `desktop.displayManager` module unifies display-manager selection.
- `host.class` (enum) is used to gate desktop-only Stylix targets so
  headless hosts don't pull GNOME assets.

## Removed Infrastructure

The following are intentionally absent from the current configuration:

- Prometheus / Grafana / Loki / Alertmanager monitoring stack — system
  insight is now via `journalctl`, `systemctl`, and per-service logs.
- `nix-colors` input (replaced by Stylix base16).
- `termshark`, `wireshark`, `reddix`, `wasistlos`, `steampipe` modules
  and the standalone `cosmic-applet-package-updater` chain.
- `vim` from the base user package set (Home Manager `vimAlias`
  handles it).
- `cosmic-ext-applet-radio` as an upstream input — replaced by a local
  module workaround for an upstream `mkPackageOption`/`description`
  bug.

## Development Workflow

```bash
gh issue develop <n> --checkout    # Branch from issue
just test-host <host>              # Build the change
just validate                      # Syntax + checks + flake check
git commit -m "type(scope): summary (#n)"
gh pr create --fill                # Open PR
nhs <host>                         # After merge: lock-aware deploy
```

## Automated Package Updates

Four packages are tracked here rather than taken from nixpkgs, because we
follow their upstreams faster than nixpkgs does. Every release used to mean a
manual version + hash bump.

`.github/workflows/package-autoupdate.yml` does it nightly at 03:43 UTC:
resolve upstream → rewrite version + hash → build → open PR → merge. The
config is updated before you wake up. Deploying stays manual.

| Package          | Upstream source                | Update script                       |
|------------------|--------------------------------|-------------------------------------|
| `claude-code`    | Anthropic GCS `latest` channel | `update-claude-code-native.sh`      |
| `claude-desktop` | Anthropic signed apt repo      | `update-claude-desktop.sh`          |
| `warp-terminal`  | `app.warp.dev` redirect chain  | `update-warp-terminal.sh`           |
| `antigravity`    | `Hy4ri/antigravity-flake`      | `update-antigravity.sh`             |

### Design

**The logic lives in `scripts/`, not in YAML.** Each script is idempotent,
writes nothing when already current, and has a `--check` mode. The bump you
get at 03:43 is one you can run and debug by hand:

```bash
./scripts/update-warp-terminal.sh --check   # exit 1 if a bump is available
./scripts/update-antigravity.sh             # apply it
```

The workflow then reduces to: run script → did `git diff` change anything →
build → merge. No update logic is trapped in a YAML `run:` block where it can
only be tested by pushing a commit.

**Verification runs inline, then the same job merges.** Pull requests opened
with `GITHUB_TOKEN` do not trigger other workflows, so `ci.yml` never runs on
them and `gh pr merge --auto` would wait forever on checks that never arrive.
The job that merges is therefore the job that built it.

**`max-parallel: 1`.** Each matrix leg merges to `main`; running them
concurrently just leaves the later ones rebasing against a moved base.

### Traps worth knowing

Most of these cost real debugging time. If you are building something
similar, they are the reason this page exists.

- **`magic-nix-cache` is retired.** It fails with `Cache service responded
  with 400` and `Our services aren't available right now`. Replaced with
  `cachix/cachix-action` against our own cache.
- **Check that your cache secret actually exists.** `update-flake.yml` had
  referenced `secrets.CACHIX_AUTH_TOKEN` since the day it was written, but the
  secret was never set — so the step was a silent no-op and every CI run
  rebuilt from source. `cachix-action` does not fail loudly on an empty token.
- **Actions cannot open PRs by default.** The job dies with `GitHub Actions is
  not permitted to create or approve pull requests`. It is a repository
  setting, not a workflow permission:

  ```bash
  gh api -X PUT repos/OWNER/REPO/actions/permissions/workflow \
    -f default_workflow_permissions=write \
    -F can_approve_pull_request_reviews=true
  ```

- **Verify the attribute you actually changed.** The antigravity job built
  `pkgs.antigravity-cli`, which resolves to a *flake input's* package —
  ours is `pkgs.customPkgs.antigravity-cli`, a different derivation at a
  different version. The gate passed green without touching a single file the
  script had rewritten. A build gate pointed at the wrong attribute is worse
  than no gate, because it reads as proof.
- **Never trust an upstream index to be sorted.** Anthropic's apt `Packages`
  file lists every historical release in arbitrary order. Reading it top-down
  returned a version *11,000 releases behind* the one we had pinned — and it
  would have built fine, silently downgrading the package by more than a year.
  `sort -V` is load-bearing.
- **Anchor rewrites on a key, not a position.** The claude-code derivation
  carries one hash per platform. A positional `sed` will happily swap them,
  and the mistake only surfaces as a hash mismatch on the architecture you do
  not build.

## Troubleshooting

```bash
just check-syntax                  # Syntax errors
just diff <host>                   # Pending closure delta
nix flake check --show-trace       # Detailed evaluation errors
journalctl -u <service> -f         # Follow service logs
sudo nixos-rebuild switch --rollback   # Roll back to previous generation
```

## Documentation

- [docs/UPDATE-DEPLOY.md](./docs/UPDATE-DEPLOY.md) — `nhs` /
  `just update-commit-deploy` reference (local + remote).
- [docs/PATTERNS.md](./docs/PATTERNS.md) — NixOS patterns and best
  practices (read before writing modules).
- [docs/NIXOS-ANTI-PATTERNS.md](./docs/NIXOS-ANTI-PATTERNS.md) —
  Anti-patterns and review checklist.
- [docs/MCP-GUIDE.md](./docs/MCP-GUIDE.md) — MCP server integration.
- [docs/guides/GITHUB-WORKFLOW.md](./docs/guides/GITHUB-WORKFLOW.md) —
  Issue-driven development workflow.
- [docs/guides/CACHE-STRATEGY.md](./docs/guides/CACHE-STRATEGY.md) —
  Binary cache configuration.
- [docs/guides/PACKAGE-SYSTEM-USAGE.md](./docs/guides/PACKAGE-SYSTEM-USAGE.md)
  — Package categorisation.
- [docs/README.md](./docs/README.md) — Full documentation index.

## License

See [LICENSE](./LICENSE).
