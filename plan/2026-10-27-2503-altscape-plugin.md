---
status: approved
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
       local.omarchy.enableOnce = [ id ];   # from omarchy-enable-once.nix (step 4a)
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
   - The module imports `./omarchy-enable-once.nix` (step 4a) and enables
     Altscape through it, with no hook of its own.
   - A short header comment in the style of `omarchy-ai-mirror.nix`, saying
     what it installs and that no manual step is needed.

   → verify: `just check-syntax`; the step 6 builds.
   Traps: AGENTS.md says reach nixarchy via `inputs.nixarchy`, never
   `config.programs.nixarchy.package` (infinite recursion). Explicit imports
   only. Escape `''${…}` inside Nix strings.

   **Step 4a: `hosts/common/nixos/omarchy-enable-once.nix` (new), shared with #2505.**
   (approved in spec/2026-10-27-2505-omateams-plugin.md §2). It is a NixOS
   module that adds a Home Manager option to
   `home-manager.sharedModules`: `local.omarchy.enableOnce` (`listOf str`,
   default `[ ]`, merged across modules). When non-empty, it writes
   `xdg.configFile."omarchy/hooks/post-boot.d/enable-once"` (executable). The
   hook body:

   - markers in `${XDG_STATE_HOME:-$HOME/.local/state}/nixarchy-local/enabled-once/<id>`;
     exit 0 if every id has one;
   - `OMARCHY_SHELL_IPC_TIMEOUT=${OMARCHY_SHELL_IPC_TIMEOUT:-30s}`;
   - wait up to 120 × 1 s for `omarchy-shell shell ping`, exit 0 if it never
     answers;
   - `omarchy-shell shell rescanPlugins || true`;
   - for each id still missing: if `out=$(omarchy-plugin-enable "$id" 2>&1)`
     succeeds, `mkdir -p` and touch the marker; otherwise send `$id: $out` to
     `systemd-cat -t omarchy-enable-once`.

   PATH: check how nixarchy's own `default-plugins` hook gets `omarchy-shell`
   and `omarchy-plugin-enable` (it uses `cfg.package` inside nixarchy; we
   can't, see Traps). If both are on the session PATH (`command -v` in a
   session shell), use plain names and prefix only coreutils and systemd.
   Never `config.programs.nixarchy.package`.
   → verify: `nix eval …p620…home-manager.users.olafkfreund.xdg.configFile."omarchy/hooks/post-boot.d/enable-once".text`
   prints the hook with `io.github.qempexe.altscape`, and `bash -n` on it
   passes.

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
     - Run `~/.config/omarchy/hooks/post-boot.d/enable-once` once by hand
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

## Implementation notes (2026-10-27)

- Step 4: the Home Manager block is a function (`{ lib, ... }:`) so
  `lib.hm.dag` resolves. As a NixOS module's `lib` it did not, and both host
  builds failed.
- Step 4: the `require` append runs inside `run` via `bash -c`, so a dry run
  cannot write to `bindings.lua`.
- Deviation, from the review: the settings key is **Super+Alt+Shift+W**, not S.
  S is already "Nixi companion: listen" on both hosts, and Hyprland would run
  both. W is free on p620 and razer (checked with `hyprctl -j binds`).
- Review gap, accepted and documented in the module header: Alt+Tab replaces
  Omarchy's default unconditionally, so it does nothing while the plugin is
  off (first login before the hook runs, or turned off in Setup > Plugins).
- The stub's `active` check also matches a bind description containing
  "Altscape", as upstream's `bind_live` does.
- Known minor: on a brand-new home with no `bindings.lua` yet, the `require`
  line lands at the next activation. Both hosts have the file.
