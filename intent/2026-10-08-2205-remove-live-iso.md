---
status: draft
issue: 2205
author: olafkfreund
---

# Intent: remove the per-host live installer ISO path

## Problem

The repo carries a per-host live installer ISO path that nobody uses and that
no longer works. Installer images for users are nixarchy's job
(`packages.iso` / `packages.iso-net` from its `installer/cd.nix`); we never
image the running hosts.

What is here is broken in four ways:

1. `lib/live-images.nix` defines p620, razer and p510 ISOs, but `flake.nix`
   publishes only `live-iso-razer`, so `just build-live p620|p510` and
   `just build-all-live` fail.
2. The built file is `nixos-minimal-<ver>-x86_64-linux.iso`; `just flash-live`
   looks for `nixos-<host>-live.iso` and never finds it.
3. `modules/installer/` is imported by nothing and uses impure `<nixpkgs>`.
4. `modules/development/nix.nix` installs `pkgs.nixos-generators`, archived
   upstream (superseded by `nixos-rebuild build-image` since 25.05), and nothing
   calls it.

Dead code that looks usable costs whoever reaches for it in an emergency, and
the agent tooling advertises it: the `/nix-live` command
(`.claude/commands/nix-live.md`, `.gemini/commands/nix-live.toml`) and its
mention in `/nix-help` tell agents to run recipes that fail.

## Proposed outcome

- No live ISO package, app, recipe, module or helper script remains.
- `nixos-generators` is no longer in any host closure.
- The README and the agent commands no longer describe a live-USB path.
- `grep -rn "live-iso\|liveImages\|install-helpers\|nixos-generators"`
  finds nothing outside `docs/` history and these artifacts.
- All three hosts still evaluate and build.

## Affected users and systems

- `flake.nix` (`liveImages` binding, `live-iso-razer` package, `build-live` app)
- `lib/live-images.nix`, `modules/installer/`, `scripts/install-helpers/`
- `tools/default.nix` (`build-live`)
- `Justfile` live recipes (`build-live`, `build-all-live`, `flash-live`,
  `clean-live`, `test-live-config`, `live-help`, `test-hw-config`,
  `show-devices`), all of which serve only the installer
- `modules/development/nix.nix` (`pkgs.nixos-generators`): every host
  importing the development module loses one package
- `README.md` live-USB section and the `lib/` line naming `live-images`
- `.claude/commands/nix-live.md`, `.gemini/commands/nix-live.toml`, the
  `/nix-help` line referencing them, `.gemini/state/topology.json` entries
- No `docs/` page and no mkdocs nav entry refers to it, so both nav files
  stay as they are.

## Constraints

- Removal only; no replacement installer here. User installers stay in nixarchy.
- No deploy needed beyond the normal flow; p510 is not built or deployed
  without asking, so it is verified by evaluation and the CI/`quick-test` build.
- Never check out the branch in `~/.config/nixos`; the work is in the
  `../nixos-2205` worktree.

## Open questions

1. Remove the `/nix-live` agent command (Claude and Gemini) entirely, rather
   than rewriting it to point at nixarchy's ISO? Proposed: remove.
2. `.gemini/state/topology.json` looks generated. Edit its two entries by hand,
   or leave it for its generator to refresh? Proposed: edit by hand.
