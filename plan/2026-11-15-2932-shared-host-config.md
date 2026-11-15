---
status: draft
issue: 2932
spec: spec/2026-11-15-2932-shared-host-config.md
coders:
  1: codex  # template moves across three hosts, iterated block by block against the evaluated .drv
  2: codex  # the p620+razer fragment with mkDefault/override splits, same loop
  3: codex  # identical nixarchy scalar options into one fragment, same loop
reviewers:
  - codex
  - agy
---

# Plan: move duplicated host configuration into shared files

Approved decisions: move only blocks that are identical across the hosts that get them (or shared `mkDefault`
scalars whose differing leaves stay in the host at normal priority) into (1) `hosts/templates/desktop.nix` for all
hosts, (2) a new `hosts/common/nixos/dev-workstation.nix` imported by p620 and razer, (3) a new
`hosts/common/nixos/omarchy-desktop.nix` holding only identical scalar `programs.nixarchy` lines, imported by
`hosts/{p620,razer}/nixos/nixarchy.nix`. Stay per host: every `environment.systemPackages` list, the explicit
`containers/docker.nix` imports, the `omarchy-*` import lists (order feeds a generated script), `nfs.server`,
`nixpkgs.config`, `users.users`, `age.identityPaths`, signing keys, firewall, xserver/GPU lists, p510-only config.

**The rule:** after each block move, `SNAP_NO_BUILD=1 scripts/config-snapshot.sh snap /tmp/s4-<n>` then
`scripts/config-snapshot.sh diff <baseline> /tmp/s4-<n>` must print `IDENTICAL` for p620, razer and p510. If a move
changes a host's `.drv`, revert that move and leave the block per host. No order-only exception. Baseline: `main`
@ the commit this branch is based on (`git merge-base HEAD origin/main`), snapshot directory given by the lead.

## Block map (re-check line numbers before editing; taken on `5a01ce4c8`)

| Block | p620 | razer | p510 | Target |
|---|---|---|---|---|
| 5 common `hosts/common/nixos` imports | 25-29 | 22-26 | 26-30 | 1 |
| `modules/development/default.nix`, `secrets/api-keys.nix` imports | 37, 39 | 34, 36 | 38, 39 | 1 |
| `aiDefaults.enable` (template already sets it) | 112-114 | 137-139 | 101-103 | delete |
| `features.security`, `features.syncthing` | 322-333 | 206-217 | 139-150 | 1 |
| `features.gnome-remote-desktop.enable` | 293-295 | 178-180 | 325-327 | 1 |
| `desktop.displayManager.backend`, `defaultSession`, `desktopManager.gnome.enable` | 420, 429, 663 | 304, 313, 460 | 401-422 | 1 (p510 keeps `autoLogin`) |
| `system.stateVersion` | 559 | 660 | 548 | 1 |
| `security/secrets.nix`, meeting-transcribe, agent-voice, swarm-reaper imports | 38, 46, 49, 50 | 35, 38-40 | — | 2 |
| `modules.security.secrets.enable`, `secrets.apiKeys` | 589-591, 543-547 | 513-515, 423-427 | — | 2 |
| `features.development`/`virtualization`/`cloud`/`ai.mcp`/`programs` | 276-397 | 155-270 | — | 2, host keeps `precommit`, `azure`, `grafana`, `yt-x`, waydroid `disableGbm` |
| claude-hooks, cosmic off, intune, themeOwner, craftapps, tfm, ddcutil, citrix, rescreenshot | 127-131, 402-409, 497-539 | 172-176, 275-282, 318-392 | — | 2 (rescreenshot `user` from the `username` module arg) |
| claude-code-managed/mods/router-cli, swarm reaper, agentVoice common part | 250-263, 485-492 | 406-420, 677-685 | — | 2, razer keeps `summary.backend` |
| playerctld + user-unit restart, fwupd, ydotool | 672, 806, 673, 874 | 468, 464, 469, 636 | — | 2 (p620 keeps fwupd `LimitNOFILE`) |
| identical `programs.nixarchy` scalars | nixarchy.nix | nixarchy.nix | — | 3 |

## Steps

1. Spec Design 1 into `hosts/templates/desktop.nix` (paths relative to `hosts/templates/`: `../common/nixos/...`,
   `../../modules/...`), removing the lines from all three hosts in the same edit. One block at a time, rule above.
   Traps: never `mkDefault` a list; `system.stateVersion = "25.11"` exactly.
2. Spec Design 2 into new `hosts/common/nixos/dev-workstation.nix`, imported from `hosts/{p620,razer}/configuration.nix`.
   Shared scalars a host overrides get `lib.mkDefault` in the fragment; the host keeps the override. Rule above.
3. Spec Design 3 into new `hosts/common/nixos/omarchy-desktop.nix`, imported from `hosts/{p620,razer}/nixos/nixarchy.nix`
   (as the last import). Rule above.
4. Docs (Claude): `docs/architecture/template-system.md` and `hosts/README.md` describe the three shared places and
   what stays per host. `scripts/config-snapshot.sh` gains `SNAP_NO_BUILD=1` (evaluate only), documented in
   `scripts/README.md`.

## Tests

Final: full `scripts/config-snapshot.sh snap` (with builds) + `diff`: p620, razer, p510 `IDENTICAL`.
`wc -l hosts/*/configuration.nix` before/after in the PR. deadnix and statix on changed files; `just check-syntax`;
CI green; `@codex review` clean. The PR lists every block that had to stay per host because it changed a `.drv`.

## Rollback

Revert the squash commit.
