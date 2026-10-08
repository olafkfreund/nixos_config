---
status: draft
issue: 2205
intent: intent/2026-10-08-2205-remove-live-iso.md
---

# Spec: remove the per-host live installer ISO path

## Design

Pure deletion. Nothing is renamed, moved or replaced, so each removal either
leaves the flake evaluating or fails evaluation loudly.

### Flake outputs (`flake.nix`)

- Drop the `liveImages = import ./lib/live-images.nix { ... };` binding and its
  `# Live image builder` comment (lines 379-382).
- Drop `live-iso-razer` and its `# Live ISO images` comment from `packages`
  (lines 605-606).
- Drop the `build-live` app (lines 650-653).

### Builders and modules

- Delete `lib/live-images.nix`, `modules/installer/` (`default.nix`,
  `live-system.nix`, `installer-tools.nix`) and `scripts/install-helpers/`
  (`install-wizard.sh`, `mount-filesystems.sh`, `parse-hardware-config.py`,
  `partition-disk.sh`). Their only consumers are each other, the Justfile
  recipes and the flake lines above.
- `tools/default.nix`: delete the `build-live` attribute (line 164 up to the
  `dev-utils` attribute at line 248). `deploy`, `test` and `dev-utils` stay.
- `modules/development/nix.nix`: delete the `pkgs.nixos-generators` line.

### Justfile

Delete the whole `Live USB Installer Commands` section, from its banner at
line 1181 up to the `MicroVM Management Commands` banner at line 1334:
`build-live`, `build-all-live`, `flash-live`, `test-hw-config`, `show-devices`,
`clean-live`, `test-live-config`, `live-help`. `test-hw-config` calls
`scripts/install-helpers/`, and `show-devices` exists only to pick a
`flash-live` target, so neither has another use.

### Docs and agent tooling

- `README.md`: delete the `## Live Installer` section (lines 224-236) and drop
  `, live-images` from the `lib/` line (line 124).
- Delete `.claude/commands/nix-live.md` and `.gemini/commands/nix-live.toml`
  (decided in the intent: remove, not rewrite).
- `.claude/commands/nix-help.md`: delete the `/nix-live` entry (line 76 to
  the line before `/nix-microvm`) and its row in the table (line 324).
- `.gemini/state/topology.json`: delete the two `modules/installer/*` entries
  by hand (decided in the intent).
- `docs/` and both mkdocs nav files: unchanged. Nothing there refers to the
  live path.

## Alternatives rejected

- **Fix the path instead** (publish all three ISOs, set `image.baseName` so
  `flash-live` finds the file). Rejected: no one images the running hosts, and
  user installers already live in nixarchy. Fixing it means maintaining a
  second installer for no user.
- **Replace `nixos-generators` with `nixos-rebuild build-image` recipes.**
  Rejected: nothing here builds images, so the replacement would be as dead as
  what it replaces.
- **Rewrite `/nix-live` to point at nixarchy's ISO.** Rejected in the intent:
  nixarchy documents its own installer, and a pointer command would only rot.

## Risks

- **A host closure changes.** Removing `nixos-generators` changes the system
  closure of every host that enables the development module, which is the
  intended effect. No service or activation logic is involved, so nothing
  restarts beyond the normal profile switch.
- **Hidden references.** A recipe or script outside the grep could call a
  deleted recipe. Mitigated by the grep below and `just --list`, which parses
  the whole Justfile.
- **p510.** It is not built or deployed locally without asking. It is verified
  by evaluation, and by the CI build that runs on the PR.

## Verification

1. This prints nothing:

   ```bash
   grep -rn "live-iso\|liveImages\|live-images\|install-helpers\|nixos-generators" --exclude-dir=.git . \
     | grep -v "^./\(docs\|intent\|spec\|plan\)/"
   grep -rn "build-live\|flash-live\|nix-live" --exclude-dir=.git . \
     | grep -v "^./\(docs\|intent\|spec\|plan\)/"
   ```

2. `just --list` succeeds (the Justfile still parses).
3. `just check-syntax` passes.
4. `nix flake check --no-build` evaluates. `nix eval .#packages.x86_64-linux --apply builtins.attrNames`
   has no `live-iso-razer`, and the `apps` set has no `build-live`.
5. `just test-host p620` and `just test-host razer` build. p510 is checked with
   `nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`
   only, and its full build is left to CI.
6. `nix path-info -r` on the p620 toplevel contains no `nixos-generators`.
