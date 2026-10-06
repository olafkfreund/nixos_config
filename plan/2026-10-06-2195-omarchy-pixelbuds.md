---
status: approved
issue: 2195
spec: spec/2026-10-06-2195-omarchy-pixelbuds.md
---

# Plan: Pixel Buds plugin in the Omarchy bar on p620 and razer

## Approved decisions

- Package the fork
  [olafkfreund/nixarchy-pixelbuds](https://github.com/olafkfreund/nixarchy-pixelbuds),
  which is upstream `rdoupe/omarchy-pixelbuds` 2.0.0, with its own
  `flake.nix`. This repo takes it as a flake input.
- Rename the plugin id `io.github.rdoupe.pixelbuds` → `nixarchy.pixelbuds`
  in `manifest.json` id, `Panel.qml` moduleName/ipcTarget and the README.
  Nothing else is renamed: the bridge D-Bus object path, the
  `omarchy-pixelbuds/` cache and lock dirs, and the tests stay as they are.
- Do not edit the upstream path literals. The flake copies the runtime files
  and patches store paths into the copies at build time:
  - `/usr/bin/python3` → `python3.withPackages (p: [ p.pygobject3 ])`
  - `/usr/bin/gdbus` → `glib.bin`
  - `/usr/bin/omarchy-shell` → `/run/current-system/sw/bin/omarchy-shell`

  The replacements use `--replace-fail`.
- `trustedPath "/usr/bin:/bin"` and the `clearEnvironment` allowlists stay.
  Checked: the Nix Python with pygobject3 imports Gio/GLib under `env -i`.
- Hosts: p620 and razer only. Register through
  `programs.nixarchy.plugins."nixarchy.pixelbuds".src`. No `features.*`
  flag, no `modules/` file and no systemd unit, because it is a plugin
  registration like the other `hosts/common/nixos/omarchy-*.nix` files.
- Adding it to the bar stays manual:
  `omarchy plugin enable nixarchy.pixelbuds --section right`.
- Keep the attribution: `LICENSE` (MIT), `LICENSE-APACHE`, `NOTICE`, and
  manifest `author`/`license`.

## Steps

Steps 1–3 run in the fork, in a clone at
`~/Source/GitHub/nixarchy-pixelbuds` on branch `feat/nix-flake` cut from
`origin/main`. Steps 4–6 run in this repo's worktree
`~/.config/nixos-2195` (branch `feat/2195-omarchy-pixelbuds`).

1. **Fork: rename the id.**
   - `manifest.json:3`: `"id": "nixarchy.pixelbuds"`.
   - `Panel.qml:15-16`: set `moduleName` and `ipcTarget` to
     `"nixarchy.pixelbuds"`.
   - `README.md`:
     - Lines 32, 91, 111, 116 and 117: replace `io.github.rdoupe.pixelbuds`
       with `nixarchy.pixelbuds`.
     - Line 85: change the clone URL to
       `https://github.com/olafkfreund/nixarchy-pixelbuds.git`.
     - Add a `## NixOS / nixarchy` section after `## Install` showing
       `programs.nixarchy.plugins."nixarchy.pixelbuds".src = inputs.nixarchy-pixelbuds.packages.${system}.default;`
       followed by the enable command.
     - Add one line at the top saying this is a fork of
       `rdoupe/omarchy-pixelbuds`.

   Verify: `grep -rn "io.github.rdoupe.pixelbuds" --exclude-dir=.git .`
   prints nothing.

   Traps: the D-Bus path `/io/github/rdoupe/pixelbuds/maestro_*` in
   `bridge/pixelbuds_bridge.py` and `tests/python/test_dbus_integration.py:198`
   is not the id, so leave it. Do not write `pacman` or `yay` anywhere, because
   nixarchy's plugin validator fails the rebuild on them.

2. **Fork: add `flake.nix`**, modelled on `olafkfreund/nixarchy-microvm`'s
   flake: `systems = [ "x86_64-linux" "aarch64-linux" ]`, `inputs.nixpkgs`
   = nixos-unstable, and `manifest` read from `manifest.json` for the
   version.

   `packages.<system>.{default,nixarchy-pixelbuds}` is a `runCommand` with
   these parts:
   - `mkdir -p $out/bridge`, then plain `cp` of `manifest.json Model.js
     Panel.qml Service.qml LICENSE LICENSE-APACHE NOTICE preview.png` into
     `$out`, and of `bridge/{pixelbuds_bridge,maestro,casecache}.py` into
     `$out/bridge/`.
   - `substituteInPlace $out/Service.qml --replace-fail '"/usr/bin/python3"'
     '"${py}/bin/python3"' --replace-fail '"/usr/bin/gdbus"'
     '"${pkgs.glib.bin}/bin/gdbus"'`, where
     `py = pkgs.python3.withPackages (p: [ p.pygobject3 ])`.
   - `substituteInPlace $out/Panel.qml --replace-fail '"/usr/bin/omarchy-shell"'
     '"/run/current-system/sw/bin/omarchy-shell"'`.
   - Also set `meta` (description, homepage = fork URL,
     `licenses = [ mit asl20 ]`, `platforms.linux`).

   Verify: `nix build .#default && grep -rn /usr/bin result/*.qml` prints
   nothing, `grep -n /nix/store result/Service.qml` shows both binaries, and
   `find result -type l` is empty.

   Traps:
   - Use plain `cp`, not `symlinkJoin` or `linkFarm`:
     `omarchy-plugin-validate` refuses symlinks.
   - `cp` from the store leaves files read-only, so `chmod -R u+w $out`
     before `substituteInPlace`.
   - Keep `bridge/` as a subdirectory. Do not flatten it: `Service.qml:30`
     resolves `bridge/pixelbuds_bridge.py`.
   - The bridge's `#!/usr/bin/python3 -I` shebangs are never executed
     (`Service.qml:222` passes the file to the interpreter), so leave them.

3. **Fork: add `checks.<system>.default`.** This is a `runCommand` with
   `nativeBuildInputs = [ py pkgs.dbus pkgs.jq pkgs.nodejs ]`. It does the
   following:
   - Copy `${./tests}` to `tests`, and the built package's `bridge/` and
     `Model.js` next to it, all writable. Then, in the copy only:
     - `substituteInPlace tests/python/test_dbus_integration.py
       --replace-fail '"/usr/bin/dbus-daemon"' '"${pkgs.dbus}/bin/dbus-daemon"'
       --replace-fail '["/usr/bin/python3"' '["${py}/bin/python3"'`
     - set `"PATH": "/usr/bin:/bin"` there to `"${py}/bin"` if the
       test needs it, and only then.
   - `cd tests/python && python3 -B -m unittest discover -s . -p 'test_*.py'`.
   - `node tests/js/model-test.js`.
   - Do not run `tests/launch-boundary-test.sh`. It asserts the upstream
     `/usr/bin` literals, which the package replaces by design.
   - Assertions on the package:
     - `! grep -rn /usr/bin $plugin --include='*.qml'`
     - `jq -e '.id == "nixarchy.pixelbuds"' $plugin/manifest.json`
     - every `.entryPoints[]` file exists
     - `find $plugin -type l` is empty
     - `env -i ${py}/bin/python3 -I -B -c 'import gi;
       gi.require_version("Gio","2.0"); gi.require_version("GLib","2.0");
       from gi.repository import Gio, GLib'`

   Then `nix flake check`, commit flake.nix + flake.lock, push the branch,
   open a PR on the fork, and merge it after the user has read it.

   Verify: `nix flake check` passes.

   Traps:
   - The D-Bus integration test starts a private `dbus-daemon` with a unix
     socket in a temp dir. If the Nix sandbox blocks that, skip only that
     file (`-p 'test_[bm]*.py'`), and record the skip as a deviation in
     this plan in the same commit.
   - `support.py` resolves `REPO` relative to `tests/python`, so `bridge/`
     must sit at `../../bridge` from there.

4. **This repo: `flake.nix`.** After the `nixarchy-winvm` input
   (`flake.nix:163-166`), add a comment and this input:

   ```nix
   # nixarchy-pixelbuds: Pixel Buds battery + ANC bar plugin (fork of
   # rdoupe/omarchy-pixelbuds); hosts/common/nixos/omarchy-pixelbuds.nix.
   nixarchy-pixelbuds = {
     url = "github:olafkfreund/nixarchy-pixelbuds";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

   Then `nix flake lock --update-input nixarchy-pixelbuds`. Only that input
   may change in `flake.lock`.

   Verify: `git diff flake.lock` touches only `nixarchy-pixelbuds`.

   Traps: do this only after step 3 is merged to the fork's `main`. The
   input tracks `main`, not `feat/nix-flake`.

5. **This repo: add `hosts/common/nixos/omarchy-pixelbuds.nix`.**

   ```nix
   # nixarchy-pixelbuds: Pixel Buds Pro battery (per bud + case) and
   # listening modes in the Omarchy bar. The fork's flake patches upstream's
   # /usr/bin/python3, gdbus and omarchy-shell to store paths (#2195).
   #
   # One-time step per machine:
   #   omarchy plugin enable nixarchy.pixelbuds --section right
   { inputs, ... }:
   {
     home-manager.users.olafkfreund =
       { pkgs, ... }:
       {
         programs.nixarchy.plugins."nixarchy.pixelbuds".src =
           inputs.nixarchy-pixelbuds.packages.${pkgs.stdenv.hostPlatform.system}.default;
       };
   }
   ```

   Verify: `just check-syntax`.

   Traps: do not import the fork's flake as a HM module, because it has none.

6. **This repo: import it on both hosts.** Add
   `../../common/nixos/omarchy-pixelbuds.nix` right after
   `../../common/nixos/omarchy-omamail.nix` in
   `hosts/p620/nixos/nixarchy.nix:38` and
   `hosts/razer/nixos/nixarchy.nix:37`.

   Verify: `just test-host p620` and `just test-host razer` both build.
   The nixarchy validator runs `omarchy-plugin-validate` inside the build.

   Traps: build razer on p620 if it is heavy
   (`nixos-rebuild build --build-host`). Never build p510. Never `git
   checkout` in `~/.config/nixos`; work only in the worktree.

## Tests

- Fork: `nix flake check` passes, and so does the `nix build` grep from
  step 2.
- This repo: `just check-syntax`, `just test-host p620` and
  `just test-host razer` all pass.
- Runtime, after a deploy the user runs (p620 local, razer
  `just deploy-via-p620 razer`), announced on the bus first:
  - `ls ~/.config/omarchy/plugins/nixarchy.pixelbuds/bridge` lists the
    three `.py` files.
  - `omarchy plugin enable nixarchy.pixelbuds --section right`, then
    restart the shell.
  - With the buds connected, the icon appears and the panel shows battery
    for both buds and the case.
  - `omarchy-shell nixarchy.pixelbuds cycleAnc` changes the mode.
  - The shell log has no Python traceback.

## Rollback

- This repo: revert the PR (input, the new host file and the two imports).
  At the next deploy the plugin directory disappears. If the plugin was
  enabled, the stale `nixarchy.pixelbuds` entry in
  `~/.config/omarchy/shell.json` is ignored, or can be removed with
  `omarchy plugin disable nixarchy.pixelbuds`.
- Fork: revert the merge commit on `main`. Nothing else depends on it.

## Execution

Steps 1–6 edit files in two repos, so per policy the `coder` agent
(Sonnet) implements them. Steps go one at a time over `SendMessage`. A fresh
Opus agent reviews the result against this plan and `git diff`. Merging the
fork PR (between steps 3 and 4) is the user's call.
