---
status: draft
issue: 2932
intent: intent/2026-11-15-2932-shared-host-config.md
---

# Spec: move duplicated host configuration into shared files

## Design

Three shared places, filled only with blocks that are textually identical across the hosts that get them, or whose
differences become per-host overrides at normal priority over a shared `mkDefault` scalar.

1. **`hosts/templates/desktop.nix` (all three hosts).** Add the five `hosts/common/nixos` imports (i18n, envvar,
   host-class, zfs-import, inotify-limits), `modules/development/default.nix` and `modules/secrets/api-keys.nix`;
   `features.security`, `features.syncthing`, `features.gnome-remote-desktop.enable`;
   `desktop.displayManager.backend = "none"`, `services.displayManager.defaultSession`,
   `services.desktopManager.gnome.enable`; `system.stateVersion`. Remove them from the hosts in the same commit, and
   the host `aiDefaults.enable` lines (the
   template already sets it). Package lists and the explicit `modules/containers/docker.nix` imports stay where they
   are: moving them changes package order inside `environment.systemPackages` (Codex review).
2. **`hosts/common/nixos/dev-workstation.nix` (p620 and razer).** Imports of `modules/security/secrets.nix`,
   meeting-transcribe, agent-voice and claude-swarm-reaper; the identical blocks: claude-hooks, cosmic off, intune,
   themeOwner, craftapps, tfm, ddcutil, citrix, rescreenshot-mcp, claude-code-mods, router-cli, swarm reaper,
   playerctld with its user-unit restart, fwupd, ydotool, `modules.security.secrets.enable`, `secrets.apiKeys`; and
   the shared bodies of `features.development`, `virtualization`, `cloud`, `ai.mcp`, `programs`,
   `claude-code-managed`, `agentVoice` with the differing leaves (p620 `precommit`, `azure`, `grafana`, `yt-x`;
   razer waydroid `disableGbm`, `summary.backend`) left in the host.
3. **`hosts/common/nixos/omarchy-desktop.nix` (p620 and razer).** Only the identical scalar `programs.nixarchy` option
   lines from `hosts/{p620,razer}/nixos/nixarchy.nix` (user, omarchyApps, menu, preinstallsExclude, browserThemeUser,
   portalPackage, displayManager, bootSplash, plugin lists). The `omarchy-*` import lists stay per host: their order
   differs (`omarchy-gmessages.nix`) and feeds the generated `omarchy-enable-once` script. p620 keeps
   `programs.nixarchy.defaultAgent`.

Left per host: `host.class`, networking/firewall/tailscale, `users.users`, `age.identityPaths`, nix-signing-key,
`nixpkgs.config`, `videoDrivers`, docker `dataRoot`, meetingTranscribe, flux, razer's GRD `mkForce` lines, all
`environment.systemPackages` lists, the `nfs.server` block (its input differs: razer disables exports on purpose),
`services.xserver` (its `xserverArgs`/`videoDrivers` lists differ), and everything p510-specific.

## Alternatives rejected

- A `features.roles.developer` NixOS option module: changes the option surface; that is phase 6 (#2934).
- One big shared file for all three hosts with `mkIf host == ...`: hides per-host differences instead of removing them.

## Risks

- Option priority or list-merge changes when a value moves: caught by the identical `.drv` check, per host.
- Import order changes the merge order of list options: visible as a `.drv` change. Rule: any move that changes a
  host's `.drv` is reverted and that block stays per host. No order-only exception.

## Verification

`scripts/config-snapshot.sh` against the `main` baseline: p620, razer, p510 `IDENTICAL`. Host file line counts
before/after recorded in the PR. `just check-syntax`, deadnix, CI, `@codex review`.
