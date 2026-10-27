---
status: draft
issue: 2503
spec: spec/2026-10-27-2503-altscape-plugin.md
---

<!-- markdownlint-disable MD013 -->

# Plan: Altscape Alt+Tab switcher on p620 and razer, set up so it sticks

## Decisions carried from the approved spec

- Package Altscape 1.0.2 at `3f99f8fd814b61261685865d55271670afb4b8e8` as
  `pkgs/altscape`, modelled on `pkgs/omapop`. Every source change uses
  `substituteInPlace --replace-fail`.
- The plugin never edits Hyprland config. Its `bin/altscape-binds` is replaced
  with a status-only stub using the same CLI and JSON shape.
- Alt+Tab comes from a Nix-owned, read-only `~/.config/hypr/altscape-binds.lua`.
  A Home Manager activation step appends
  `pcall(require, "hypr.altscape-binds") -- managed by NixOS (#2503)` once to the
  end of `~/.config/hypr/bindings.lua`. It appends only and never rewrites.
- The plugin is enabled once per host by a `post-boot.d` hook, with a marker in
  `~/.local/state/nixarchy-local/enabled-once/`. It never writes `shell.json`.
- Defaults: automatic enable; Super+Tab goes back to Omarchy's default; no bar
  widget. Changing the shortcut is a one-line change in the host module.
- p620 only: remove the dead woogy7 block (`bindings.lua` lines 31–107) by hand,
  after a backup.
- Hosts: p620 and razer. p510 is not touched.

## Steps

1. **`pkgs/altscape/default.nix` (new)**, modelled on `pkgs/omapop/default.nix`
   (lines 26–60).
   - Args: `{ lib, stdenvNoCC, fetchFromGitHub, hyprland, jq, bash, writeShellScript }`.
   - `pname = "altscape-plugin"; version = "1.0.2";`
   - `src = fetchFromGitHub { owner = "qempexe"; repo = "omarchy-altscape";
     rev = "3f99f8fd814b61261685865d55271670afb4b8e8";
     hash = "sha256-PVtoTZxtE9FhOpNymurlTQXzjB7tGqzu4DDWqecuUvk="; };`
   - `dontBuild = true`. Header comment in omapop's style, including
     `# Bump against: gh api repos/qempexe/omarchy-altscape/commits --jq '.[0].sha'`.
   - `postPatch`:
     - `substituteInPlace qml/Service.qml --replace-fail 'hyprctl -j clients'
       '${hyprland}/bin/hyprctl -j clients'`. Same for `workspaces` and
       `monitors` (lines 66–68 upstream).
     - Same file: `--replace-fail '["bash", root.bindHelper'
       '["${bash}/bin/bash", root.bindHelper'`.
     - Replace `bin/altscape-binds` with the stub (step 2):
       `cp ${./altscape-binds-stub.sh} bin/altscape-binds; chmod +x bin/altscape-binds`,
       then `substituteInPlace bin/altscape-binds --subst-var-by hyprctl
       ${hyprland}/bin/hyprctl --subst-var-by jq ${jq}/bin/jq`.
   - `installPhase`: `cp -r . $out` (omapop does the same). Drop `screenshots/`
     and `preview.png` to keep the closure small.

   → verify: step 3 must be wired first. Then
   `nix build .#nixosConfigurations.p620.pkgs.customPkgs.altscape` builds, and
   `grep -c '/nix/store/.*hyprctl' result/qml/Service.qml` gives `3`.
   Traps: hash is SRI. `git add` new files before evaluating the flake. No `with lib;`.

2. **`pkgs/altscape/altscape-binds-stub.sh` (new)**, bash, `#!@bash@` or
   `#!/usr/bin/env bash` (patchShebangs turns it into a store path):
   - `sync|status|remove` (any first arg) prints one JSON line:
     `{"ok":true,"format":"lua","file":"<HOME>/.config/hypr/altscape-binds.lua","shortcut":"alt","changed":false,"active":"<A>","error":"<E>"}`.
   - `<A>` is `true` if `@hyprctl@ -j binds | @jq@ -e 'any(.[]; (.key|ascii_downcase)=="tab" and .modmask==8 and ((.arg//"")|contains("io.github.qempexe.altscape")))'`
     succeeds, `false` if it fails, and `unknown` if hyprctl errors.
   - `<E>` is empty, except that `sync super` and `sync off` give
     `Alt+Tab is set by NixOS (hosts/common/nixos/omarchy-altscape.nix)`.
   - Writes nothing and reloads nothing.

   → verify: `shellcheck`. Then
   `stat -c %Y ~/.config/hypr/*.lua > /tmp/a; result/bin/altscape-binds sync super | jq .; stat -c %Y ~/.config/hypr/*.lua | diff /tmp/a -`
   shows valid JSON with the NixOS error text, and no mtime changed.
   Traps: the pre-commit shfmt hook reformats `.sh` files.

3. **`pkgs/default.nix:60`**: after `omapop`, add

   ```nix
   # Altscape: Alt+Tab window switcher for the Omarchy shell (#2503).
   altscape = pkgs.callPackage ./altscape { };
   ```

   **`.claude/commands/check-updates.md:67`**: add a matching row
   `| pkgs/altscape | \`rev\` in \`pkgs/altscape/default.nix\` | \`gh api repos/qempexe/omarchy-altscape/commits --jq '.[0].sha'\` |`.
   → verify:`nix eval --raw .#nixosConfigurations.p620.pkgs.customPkgs.altscape.name`
   gives `altscape-plugin-1.0.2`.

4. **`hosts/common/nixos/omarchy-altscape.nix` (new)**, shaped like
   `omarchy-omapop.nix`:

   ```nix
   { config, lib, pkgs, ... }:
   let
     id = "io.github.qempexe.altscape";
     summon = "omarchy-shell shell summon ${id}";
   in
   {
     home-manager.users.olafkfreund = { config, ... }: {
       programs.nixarchy.plugins.${id}.src =
         pkgs.customPkgs.altscape.override { hyprland = <outer config>.programs.hyprland.package; };
       home.file.".config/hypr/altscape-binds.lua".text = '' …the block from spec §2… '';
       home.activation.altscapeRequire = lib.hm.dag.entryAfter [ "writeBoundary" ] '' … '';
       xdg.configFile."omarchy/hooks/post-boot.d/altscape-enable" = { executable = true; text = '' … ''; };
     };
   }
   ```

   - Bind the outer NixOS `config` (rename it `osConfig` or use a `let`
     before the HM function) so the hyprland override uses the system
     compositor, as omapop does.
   - The binds file content is exactly the 7 lines in spec §2, with `${summon}`.
   - `altscapeRequire`:
     `f="$HOME/.config/hypr/bindings.lua"; if [ -f "$f" ] && ! grep -qF '"hypr.altscape-binds"' "$f"; then run printf '\n%s\n' 'pcall(require, "hypr.altscape-binds") -- managed by NixOS (#2503)' >> "$f"; fi`.
     Use `run` so `--dry-run` is respected. Use a plain `>>` append, which
     keeps a symlinked file a symlink.
   - `altscape-enable` hook: a bash script with `PATH` from
     `lib.makeBinPath [ <nixarchy package via inputs.nixarchy, never config.programs.nixarchy.package> pkgs.coreutils pkgs.systemd ]`.
     First see how `omarchy-omapop.nix`/nixarchy reach `omarchy-shell` and
     `omarchy-plugin-enable`. If both are already on the session PATH, use the
     plain names and add only coreutils/systemd. Body:
     marker dir `${XDG_STATE_HOME:-$HOME/.local/state}/nixarchy-local/enabled-once`.
     Exit 0 if the marker exists. Wait for `omarchy-shell shell ping`, 120 ×
     1 s, and exit 0 if it never answers. Set
     `OMARCHY_SHELL_IPC_TIMEOUT=${OMARCHY_SHELL_IPC_TIMEOUT:-30s}`. Run
     `omarchy-shell shell rescanPlugins || true`. If
     `out=$(omarchy-plugin-enable ${id} 2>&1)` succeeds, write the marker;
     otherwise log `$out` with `systemd-cat -t altscape-enable`.
   - A short header comment in the style of `omarchy-ai-mirror.nix`, saying
     what it installs and that no manual step is needed.

   → verify: `just check-syntax`; the step 6 builds.
   Traps: AGENTS.md says reach nixarchy via `inputs.nixarchy`, never
   `config.programs.nixarchy.package` (infinite recursion). Explicit imports
   only. Escape `''${…}` inside Nix strings.

5. **`hosts/p620/nixos/nixarchy.nix:40` and `hosts/razer/nixos/nixarchy.nix:39`**:
   add `../../common/nixos/omarchy-altscape.nix` after `omarchy-omapop.nix`.
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".config/hypr/altscape-binds.lua".text`
   prints the block. The same eval for razer works.

6. **Build** (no edits): `just validate`; `just test-host p620`;
   `just test-host razer`. p510: `nix eval …p510…toplevel.drvPath`
   succeeds and does not change because of this work.

7. **Deploy and live checks** (session model; announce on the bus first):
   - Merge the PR, fast-forward `~/.config/nixos`, then `just p620` and
     `just deploy-via-p620 razer`.
   - p620 only, before the deploy:
     `cp ~/.config/hypr/bindings.lua ~/.config/hypr/bindings.lua.bak-2503-$(date +%s)`,
     then `sed -i '/^-- >>> Workspace Switcher (io.github.woogy7.workspaces)/,/^-- <<< Workspace Switcher$/d' ~/.config/hypr/bindings.lua`.
     Check `grep -c woogy7 ~/.config/hypr/bindings.lua` gives `0`.
   - Each host after deploy:
     - `grep -c 'hypr.altscape-binds' ~/.config/hypr/bindings.lua` gives 1.
     - Run `~/.config/omarchy/hooks/post-boot.d/altscape-enable` once by hand
       (the session is already up), then a clean `omarchy restart shell`.
     - `hyprctl reload`; `hyprctl configerrors` is empty.
     - `hyprctl -j binds | jq '[.[]|select((.key|ascii_downcase)=="tab" and .modmask==8)]|length'`
       gives 1, and its arg contains the plugin id.
     - `omarchy plugin list | grep altscape` shows enabled, and the marker
       exists.
     - `omarchy-shell shell summon io.github.qempexe.altscape next`, then
       `hyprctl -j layers` shows its layer.
     - Exactly one bar (memory: double shell).
     - Rerun `home-manager` activation by redeploying (or `just p620` again):
       the grep count stays 1.

## Tests

| Command | Expected |
|---|---|
| `nix build …customPkgs.altscape` | builds, 3 baked hyprctl paths |
| stub `sync super` + mtime diff | JSON with the NixOS error, no file touched |
| `just test-host p620` / `razer` | pass |
| after deploy: require-line count, run twice | 1 |
| `hyprctl -j binds` ALT+TAB | exactly 1, Altscape's |
| `hyprctl configerrors` | empty |
| Alt+Tab by hand (you) | opens, cycles, switches on release |

## Rollback

Revert the PR and redeploy. The binds file disappears, and because the
`require` line uses `pcall` it does nothing, so Omarchy's Alt+Tab returns.
Delete that one line from `bindings.lua` if you like. Disable the plugin with
`omarchy plugin disable io.github.qempexe.altscape` and remove the marker.
p620's woogy7 block is in `bindings.lua.bak-2503-*`.

## Implementation

Seven steps, about seven files: per policy, steps 1–5 go to one `coder` agent
(Sonnet), started from the worktree directory so it doesn't stall on the
folder-trust prompt. Steps 6–7 and the woogy7 edit stay with the session
model. Review: a fresh Opus agent given this plan and `git diff`.
