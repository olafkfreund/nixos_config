---
status: draft
issue: 2214
author: olafkfreund
---

# Intent: remove the dev-utils flake app

## Problem

The `dev-utils` flake app (`nix run .#dev-utils`) has never worked, for two
independent reasons:

1. Its program path in `flake.nix` has a stray space
   (`"${appPkgs.dev-utils} /bin/nixos-dev-utils"`), so the path it names does
   not exist.
2. Its script in `tools/default.nix` fails the shellcheck pass that
   `writeShellApplication` runs (SC2035 on `nixpkgs-fmt **/*.nix`), so the
   derivation never builds. Even if it did build, `**` without `globstar`
   reaches only one directory level.

Nothing references it: not the Justfile, not CI, not the docs. Its jobs are
already covered by Justfile recipes (`format`, `format-all`, `lint-all`) and
by the pre-commit hooks. Fixing it would mean keeping a duplicate entry point
alive that nobody has missed.

## Proposed outcome

- `nix run .#dev-utils` no longer exists, and the flake `apps` set is
  `deploy` and `test`.
- `tools/default.nix` no longer defines `dev-utils`.
- Nothing else changes: formatting and linting work exactly as they do today.

## Affected users and systems

- `flake.nix`: the `dev-utils` entry in `apps.x86_64-linux`
- `tools/default.nix`: the `dev-utils` attribute
- No host closure changes. The apps are not part of any system build.

## Constraints

- Removal only, with no replacement.
- No deploy. No host is affected, and p510 is not touched.
- The work happens in the `../nixos-2214` worktree. `~/.config/nixos` stays
  on main.

## Open questions

None.
