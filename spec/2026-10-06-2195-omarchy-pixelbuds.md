---
status: draft
issue: 2195
intent: intent/2026-10-06-2195-omarchy-pixelbuds.md
---

# Spec: Pixel Buds plugin in the Omarchy bar on p620 and razer

## Design

Two repositories change. The fork gets a flake and an id rename. This repo
takes the fork as an input and installs it on p620 and razer.

### Fork: `olafkfreund/nixarchy-pixelbuds`

Work on a branch, `feat/nix-flake`. Merge it to `main` through a PR on the
fork.

1. **Id rename** to `nixarchy.pixelbuds`, as approved:
   - `manifest.json`: `"id"`. Keep `"author": "Ryan Doupe"` and the license.
   - `Panel.qml:15-16`: `moduleName` and `ipcTarget`.
   - `README.md`: the install, remove and IPC examples use the fork URL and
     the new id. Add a short "NixOS / nixarchy" install section that
     points at the flake.
   - Leave alone: the bridge's internal D-Bus object path
     (`/io/github/rdoupe/pixelbuds/maestro_*`), the cache and lock paths
     (`omarchy-pixelbuds/`), and the tests. None of these are user-visible
     ids, and leaving them makes upstream merges cheaper.

2. **New `flake.nix`**, the same shape as `nixarchy-microvm`:
   - `packages.<system>.default` is a `runCommand` that copies only the
     runtime files with plain `cp`. `omarchy-plugin-validate` refuses
     symlinks, so `symlinkJoin` and `linkFarm` are out. The runtime files
     are `manifest.json`, `Model.js`, `Panel.qml`, `Service.qml`, `LICENSE`,
     `LICENSE-APACHE`, `NOTICE`, `preview.png`, and
     `bridge/{pixelbuds_bridge,maestro,casecache}.py`. The `bridge/`
     subdirectory is kept: `Service.qml:30` resolves
     `bridge/pixelbuds_bridge.py` relative to itself, and the bridge loads
     its siblings from its own directory.
   - Store paths are patched in at build time with `substituteInPlace`,
     on the copies only. The upstream source stays unchanged, as approved.

     | Upstream literal | Replacement | Where |
     | --- | --- | --- |
     | `"/usr/bin/python3"` | `${python3.withPackages (p: [ p.pygobject3 ])}/bin/python3` | `Service.qml:27` |
     | `"/usr/bin/gdbus"` | `${glib.bin}/bin/gdbus` | `Service.qml:28` |
     | `"/usr/bin/omarchy-shell"` | `/run/current-system/sw/bin/omarchy-shell` | `Panel.qml:43` |

     `omarchy-shell` is not in nixpkgs. It comes from the nixarchy system
     profile, and `/run/current-system/sw/bin` is the stable path for it on
     every nixarchy host. The replacement is checked through
     `--replace-fail`, so if upstream moves one of these literals the build
     fails rather than shipping a dead path.
   - `trustedPath` (`/usr/bin:/bin`) stays. It is only the child's `PATH`,
     and the bridge spawns nothing.
   - `checks.<system>.default` runs the offline test suite from a copy of
     `tests/`. In that copy, the tests' `/usr/bin/python3` and
     `/usr/bin/dbus-daemon` are rewritten to the packaged Python and
     `${dbus}/bin/dbus-daemon`. Skip `launch-boundary-test.sh`: it asserts
     the upstream `/usr/bin` literals, which hold in the source and are
     replaced in the package by design. The check then asserts:
     - the package contains no `/usr/bin/` string;
     - the manifest id is `nixarchy.pixelbuds`;
     - every manifest entry point exists;
     - the package has no symlinks;
     - the patched Python imports `gi.repository.Gio`/`GLib` under `env -i`.

     `nodejs` is added if `tests/js/model-test.js` is cheap to run.

### This repo

1. `flake.nix`: add an input next to `nixarchy-winvm`:

   ```nix
   nixarchy-pixelbuds = {
     url = "github:olafkfreund/nixarchy-pixelbuds";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

2. Add `hosts/common/nixos/omarchy-pixelbuds.nix`, shaped like
   `omarchy-microvm.nix` but without the HM module import. It sets
   `programs.nixarchy.plugins."nixarchy.pixelbuds".src` to the input's
   `packages.${system}.default`. Its header comment records the one manual
   step: `omarchy plugin enable nixarchy.pixelbuds --section right`.
3. Import it in `hosts/p620/nixos/nixarchy.nix` and
   `hosts/razer/nixos/nixarchy.nix`.

No `features.*` flag. This is a home-manager plugin registration, not a
service, and the other `omarchy-*.nix` plugin files follow the same pattern.
Nothing goes in `modules/`, and no systemd unit is added. The bridge runs
inside the user's shell session and gets no extra privileges.

## Alternatives rejected

- **Imperative `omarchy plugin add`**: crashes as soon as it starts (no
  PyGObject behind envfs's `/usr/bin/python3`), and it is not reproducible.
- **Editing `Service.qml` to look binaries up on `PATH`**: rejected at intent
  review. It also loosens upstream's deliberate trusted-path design.
- **A global `/usr/bin/python3` with PyGObject** (envfs fallback or
  `systemPackages`): rejected at intent review. It changes what every
  `/usr/bin/python3` script on the host gets.
- **`fetchFromGitHub` in this repo, no fork flake**: rejected. A flake input
  lets `nhs` bump it, and the fork's flake works on any nixarchy machine.

## Risks

- **Upstream merges**: the id rename touches `manifest.json`, `Panel.qml` and
  `README.md`, so merges can conflict on those lines. The path patching cannot
  conflict, because it never edits the source.
- **`/run/current-system/sw/bin/omarchy-shell`** assumes NixOS with nixarchy
  installing omarchy system-wide. True on p620 and razer, and already relied
  on by the earlier check. If it is ever missing, only the swipe OSD breaks;
  battery and ANC keep working.
- **No user `~/.config/omarchy/plugins/io.github.rdoupe.pixelbuds` exists**
  (checked: only other plugins there), so nothing collides with the old id.
- **Closure**: adds a Python 3 + pygobject3 env, which is small and mostly
  already in the closure on p620.
- **Hardware**: only p620 or razer with paired Pixel Buds Pro proves it
  end to end. Bluetooth on razer is the likelier one to have the buds.

## Verification

1. Fork: `nix flake check` passes. Then `nix build` and confirm by grep that
   `result/Service.qml` and `result/Panel.qml` hold store paths and no
   `/usr/bin`.
2. This repo: `just check-syntax`, then `just test-host p620` and
   `just test-host razer` build. The nixarchy validator runs
   `omarchy-plugin-validate` at build time.
3. After deploy, which is the user's call (p620 local; razer via
   `just deploy-via-p620 razer`):
   - `ls ~/.config/omarchy/plugins/nixarchy.pixelbuds`
   - `omarchy plugin enable nixarchy.pixelbuds --section right`, then
     restart the shell.
   - With the buds connected: the icon appears, battery and case readings
     show, `omarchy-shell nixarchy.pixelbuds cycleAnc` switches the mode,
     and `journalctl --user -t quickshell` (or the shell log) has no bridge
     traceback.
