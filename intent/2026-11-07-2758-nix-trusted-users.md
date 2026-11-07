---
status: draft
issue: 2758
author: olafkfreund
---

# Intent: reconsider olafkfreund in Nix trusted-users

Issue: <https://github.com/olafkfreund/nixos_config/issues/2758>, split out of #2748 (plan step 10).

## Problem

`modules/nix/nix.nix:29` sets `trusted-users = [ "root" "olafkfreund" ]`, and every host gets it
(`nix config show` on p620, razer and p510 all report `trusted-users = root root olafkfreund`).
A trusted user can pass any setting to the daemon and import unsigned store paths, so it is
root-equivalent through `/nix/var/nix/daemon-socket`. Every process running as `olafkfreund`,
each agent's shell included, holds that power. `agent-review` (#2748) hides the socket from
delegated Codex reviews only.

The daemon is not the only route. `modules/security/default.nix:7` sets
`security.sudo.wheelNeedsPassword = false` (razer restates it, `hosts/razer/configuration.nix:56`),
`nhs` relies on it (`scripts/update-commit-deploy.sh:407-411`), and `sudo -n true` succeeds on p620
as `olafkfreund`. So a same-user process keeps root through sudo even after the daemon trust goes.
Removing trust closes one interface; it does not by itself stop an agent's shell from being root.

What the trust is used for today, found read-only:

1. **Flake-level caches.** `flake.nix` `nixConfig` lists `extra-substituters`
   (cuda-maintainers, devenv, nixarchy, hyprland) and `extra-trusted-public-keys`.
   `modules/nix/flake-settings.nix` sets `accept-flake-config = true`, and the Justfile recipes
   pass `--accept-flake-config`. The daemon applies those settings only for a trusted client.
   For an untrusted one it prints `ignoring the client-specified setting ... you are not a
   trusted user`, the same failure `modules/services/nixarchy-runner.nix:213-231` documents for
   its DynamicUser runner. Most of these caches already reach system `nix.conf` from outside
   this repo (the nixarchy module): p620 has nixarchy, hyprland and devenv; razer and p510 have
   nixarchy, hyprland and `cache.nixos-cuda.org`; p510 lacks devenv; no host has
   `cuda-maintainers.cachix.org` at system level.
2. **Copying unsigned closures to another host.** No host has `secret-key-files` set, so
   ordinary (input-addressed) build outputs carry no signature unless someone signed them by
   hand. With `require-sigs = true`, importing such a path into another daemon as `olafkfreund`
   needs that user trusted on the receiving host. Content-addressed paths are the exception.
   - `nhs` remote deploys: `nh os switch --target-host HOST` (`scripts/update-commit-deploy.sh:659`);
   - `just deploy-via-p620 HOST` (`Justfile:1010-1021`): build with `--build-host p620`, then copy
     to the target with `--target-host`;
   - `just build-on-p620`, and the `--target-host`/`--build-host` recipes at `Justfile:493`,
     `502`, `868`, `978`, `983` and `1007`.

   `--build-host` is more than a closure copy: it uploads the `.drv` files and their
   dependencies, asks the remote daemon to build, then copies the outputs back to the invoking
   host. Which of those steps an untrusted user may do is not yet checked.
3. **Local work** (`nhs` on the local host, `just test-host`, `nix build`, devenv shells) needs
   trust only for the flake-level caches in point 1; the local daemon builds and substitutes for
   untrusted users.

Out of scope: the microVM guests that trust their own user (`hosts/p510/nixos/microvm/*.nix`,
`hosts/p620/microvm/flake.nix`), and the nixarchy runner, which is already handled.

## Proposed outcome

- `olafkfreund` is not in `trusted-users` on the hosts the owner agrees to, so a process
  running as that user can no longer act as root through the daemon socket. The claim is
  limited to the daemon: passwordless sudo is a separate route (open question 1).
- `nhs` (local and remote), the `just` deploy and build recipes, builds on p620 for razer, and
  `nix copy` between the hosts keep working, with no prompt they did not have before.
- The caches the flake uses today are still used: no host builds from source what it
  downloads now.
- Each host's `nix config show` and a deploy to it prove the result.

## Affected users and systems

- Hosts: p620 and razer; p510 only with the owner's agreement.
- Files: `modules/nix/nix.nix`, `modules/nix/flake-settings.nix`, `flake.nix` `nixConfig`,
  `Justfile` deploy recipes, `scripts/update-commit-deploy.sh` (`nhs`).
- Tools: nh, nixos-rebuild, `nix copy`, devenv, every agent running as `olafkfreund`.
- The owner, who runs deploys interactively.

## Constraints

- p510 changes only with the owner's agreement, and no team builds or deploys it.
- Deploys must keep working at every step. Remove a host's trust only after what replaces it is
  live on that host; one host at a time, p620 last, because it builds for the others.
- No secret in the Nix store. A signing key, if used, is an agenix file read at runtime
  (`secret-key-files` path), never `builtins.readFile`.
- Root SSH between hosts is not available today (`catalog-info.yaml:378`); a fix must not
  depend on it silently.
- No cache regression: anything trusted at system level is a named cache plus its key, not
  `trusted-substituters` that any client can enable.

## Open questions

1. **Is passwordless sudo in scope?** Without it, this task narrows one root path and leaves
   another. Recommendation: keep this issue to the daemon, and open a sibling issue for
   `wheelNeedsPassword = false` (which `nhs` and remote activation depend on), so the owner can
   weigh both together.
2. **Keep trust, narrow it, or drop it?** Recommendation: drop `olafkfreund` from
   `trusted-users`. Nix has no per-setting trust; the only narrower grants are system-level
   cache keys and signing keys.
3. **Flake-level caches.** Recommendation: move every cache the flake names into
   `nix.settings` (`substituters` and `trusted-public-keys`) in `modules/nix/nix.nix`, drop
   cuda-maintainers if `cache.nixos-cuda.org` replaced it, and stop relying on
   `accept-flake-config` for caches.
4. **Copies to remote hosts.** Choices: sign builds with a key held in agenix and trust its
   public key on the others; or keep `olafkfreund` trusted on receiving hosts only; or open the
   receiving store connection as root. Today's `--sudo` covers activation only, so that last
   option needs proof that it reaches the store connection. Recommendation: signing keys on
   every host that builds (`nhs` builds wherever it is invoked, `scripts/update-commit-deploy.sh:413`),
   covering both directions of a `--build-host` run and the paths already in the store,
   which stay unsigned until signed by hand or rebuilt. The spec settles it against a test of
   the whole `--build-host p620` run (upload `.drv`s, remote build, copy back) as an untrusted user.
5. **p510.** Recommendation: include it only after p620 and razer have run untrusted for a
   while, and only with the owner's go-ahead.
6. **Agents only, or the user too?** An alternative is a separate low-privilege Unix user for
   agents and the owner keeps trust. Recommendation: out of scope here; note it as a follow-up
   if the owner prefers it.

## Owner decisions, 2026-11-07

The owner accepted every recommendation above:

1. Passwordless sudo is out of scope here. It is tracked as #2759.
2. Drop `olafkfreund` from `trusted-users`.
3. Move every cache the flake names into `nix.settings` in `modules/nix/nix.nix`.
4. Remote copies use signing keys held in agenix, on every host that builds. The spec settles the
   details against a test of the whole `--build-host p620` run as an untrusted user.
5. p510 follows only after p620 and razer have run untrusted for a while, and only with the
   owner's go-ahead.
6. A separate user for agents is a follow-up, tracked as #2760.
