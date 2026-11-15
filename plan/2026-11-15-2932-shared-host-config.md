---
status: draft
issue: 2932
spec: spec/2026-11-15-2932-shared-host-config.md
coders:
  1: codex  # template moves across three hosts, iterated against the snapshot until IDENTICAL
  2: codex  # the p620+razer fragment with mkDefault/override splits, same loop
  3: agy    # mechanical Omarchy import-list aggregation
reviewers:
  - codex
  - agy
---

# Plan: move duplicated host configuration into shared files

Approved decisions: move only identical blocks (or shared `mkDefault` scalars with host overrides at normal
priority) into (1) `hosts/templates/desktop.nix` for all hosts, (2) a new `hosts/common/nixos/dev-workstation.nix`
imported by p620 and razer, (3) a new `hosts/common/nixos/omarchy-desktop.nix` imported by
`hosts/{p620,razer}/nixos/nixarchy.nix`. Leave lists that hosts also set, `nixpkgs.config`, `users.users`,
`age.identityPaths`, signing keys, firewall, GPU/xserver lists and p510-specific config per host. Success is
`scripts/config-snapshot.sh` `IDENTICAL` on p620, razer and p510 after every step (the implementer runs it in a loop:
edit, snapshot, diff, fix). The block map with line numbers is in the spec's Design section and was produced on
`5a01ce4c8`; re-check lines before editing.

## Steps

1. `hosts/templates/desktop.nix` + the three `hosts/*/configuration.nix`: spec Design 1. Paths in the template are
   relative to `hosts/templates/` (`../common/nixos/...`, `../../modules/...`). Remove each moved line from every
   host in the same edit; drop the explicit `containers/docker.nix` imports and host `aiDefaults.enable` lines.
   → verify: `scripts/config-snapshot.sh snap /tmp/s4 && scripts/config-snapshot.sh diff <baseline> /tmp/s4` all
   `IDENTICAL`. Traps: never `mkDefault` a list; keep `system.stateVersion = "25.11"` exactly.
2. `hosts/common/nixos/dev-workstation.nix` (new) imported from `hosts/{p620,razer}/configuration.nix`: spec Design 2.
   Shared scalar leaves that a host overrides get `lib.mkDefault` in the fragment; the host keeps the override.
   → verify: same snapshot diff. Traps: `rescreenshot-mcp` needs the username: take `username` from the module args
   (it is in `specialArgs`); `nfs.server` reads `vars`: import the host's `variables.nix` the way the host does, or
   keep that block per-host if it cannot be expressed without it.
3. `hosts/common/nixos/omarchy-desktop.nix` (new) imported from `hosts/{p620,razer}/nixos/nixarchy.nix`: spec
   Design 3. → verify: same snapshot diff.
4. Docs (Claude): `docs/architecture/template-system.md` and `hosts/README.md` describe the three shared places and
   what stays per host.

## Tests

`scripts/config-snapshot.sh` diff: p620, razer, p510 `IDENTICAL`. `wc -l hosts/*/configuration.nix` before/after in
the PR. deadnix and statix on changed files; `just check-syntax`; CI green; `@codex review` clean.

## Rollback

Revert the squash commit.
