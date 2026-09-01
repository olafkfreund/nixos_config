# Binary cache strategy

There is **no local binary cache server** on this fleet. No `nix-serve` or
`harmonia` service exists anywhere in the repo, and nothing listens on
`p620:5000`. Substitution comes entirely from public caches.

## Substituters

System-wide, from [`modules/nix/nix.nix`](https://github.com/olafkfreund/nixos_config/blob/main/modules/nix/nix.nix):

| Substituter | Purpose |
| ----------- | ------- |
| `https://cache.nixos.org` | Official NixOS cache |
| `https://nix-community.cachix.org` | Community packages |

Flake-level, from `flake.nix` `nixConfig.extra-substituters`, applied when a
command is run with `--accept-flake-config`:

| Substituter | Purpose |
| ----------- | ------- |
| `https://cuda-maintainers.cachix.org/` | Prebuilt CUDA-enabled packages |
| `https://devenv.cachix.org/` | devenv |

No personal Cachix cache is configured. `modules/nix/nix.nix` carries a
commented example if one is ever wanted.

## Making builds faster without a cache

The one real lever is **building on a faster host**. razer in particular is
slow to rebuild, so it borrows p620's CPU:

```bash
just deploy-via-p620 razer
```

This is `nixos-rebuild --build-host p620 --target-host razer`. p620 evaluates
and builds, then the closure is copied to the target over SSH. No cache server
is involved — the speedup is p620's CPU plus its already-populated
`/nix/store`, nothing more. When run on p620 itself the recipe builds locally
rather than SSHing to itself.

Other options that genuinely help:

- `just quick-deploy HOST` — skips the deploy entirely when the built
  configuration is identical to what the host is already running.
- `just test-host HOST` before deploying, so a failure costs a build rather
  than a broken switch.
- Keeping `flake.lock` current. A stale lock points at store paths that have
  aged out of cache.nixos.org and must be built locally.

## Overlays poison cache hits

An overlay applied to a deep package rebuilds everything downstream of it,
which destroys cache hits far beyond the package you overrode. Before adding
one, check whether the problem it works around still exists upstream — several
overlays in this repo's history outlived their bugs. Use `nix-diff` to see what
an overlay actually changed.

## Verifying

```bash
# What this machine will substitute from
nix show-config | grep -E 'substituters|trusted-public-keys'

# Is a given store path cached upstream?
nix path-info --store https://cache.nixos.org /nix/store/...

# How much of a build would be downloaded vs built
nix build .#nixosConfigurations.p620.config.system.build.toplevel --dry-run
```

## Related

- [Deployment guide](deployment-guide.md)
- [Update and deploy workflow](../UPDATE-DEPLOY.md)
