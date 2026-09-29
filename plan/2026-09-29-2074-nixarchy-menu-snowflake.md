---
status: approved
issue: 2074
spec: spec/2026-09-29-2074-nixarchy-menu-snowflake.md
---

# Plan: nixarchy-menu back on p620 and razer, wearing the NixOS snowflake

## Approved decisions

- nixarchy-menu stays distro-neutral, and its repo is not touched. nixarchy
  patches the plugin's `BarWidget.qml` at build time, the same way it
  already puts the snowflake on the stock `omarchy.menu` button
  (`pkgs/omarchy/menu-bar-widget.qml`).
- The patch changes only the first `WidgetButton` (`id: button`). It adds
  `labelVisible: false` and an `Image` child copied from
  `menu-bar-widget.qml`: centred, side `Math.round(button.fontSize * 1.3)`,
  `sourceSize` set to that side, `smooth` and `mipmap` on, and
  `opacity: button.dimmed ? 0.45 : 1`. The image source is
  `file://@snowflake@`, filled with
  `${nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png`. It
  must be the PNG: quickshell has no SVG image plugin.
- The patch is applied with `--fuzz=0` against nixarchy-menu `2cce175`
  (v1.0.0), so a nixarchy-menu bump that rewrites the button fails the
  build.
- The snowflake is always on wherever nixarchy-menu runs through nixarchy.
  There is no option for it.
- This repo puts back `defaultPlugins.menu = true` on p620 and razer, or
  leaves it out if nixarchy#1052 has made it the default by then, and bumps
  `flake.lock`. p510 is not changed, built or deployed.
- The nixarchy change is filed in that repo as its own issue with its own
  intent, spec and plan. They reuse this spec's design, and each goes
  through that repo's approval gates. Your other session's nixarchy
  checkout, `~/Source/nixarchy`, is on `feat/1052-menu-on-by-default`.
  That checkout is not touched: the work goes in a separate worktree.

## Steps

### nixarchy (`olafkfreund/nixarchy`)

1. Open an issue ("Put the snowflake on nixarchy-menu's bar button") that
   links nixos_config#2074. Create the worktree
   `git -C ~/Source/nixarchy worktree add ../nixarchy-<n> -b fix/<n>-menu-snowflake origin/main`.
   Write that repo's intent, spec and plan from this design, and get each
   one approved. → Verify: the three files exist on the branch with
   `status: approved`.
2. Add `pkgs/nixarchy-menu/snowflake-button.patch`. Write it as a
   `diff -u` of the pinned `BarWidget.qml` against an edited copy, so its
   context lines match `2cce175` exactly. → Verify:
   `patch --dry-run -p1 --fuzz=0 -d <menu-src> < pkgs/nixarchy-menu/snowflake-button.patch`
   applies cleanly.
3. In `modules/home.nix`, the `menu` entry of the default-plugin set:
   replace
   `src = inputs.nixarchy-menu.packages.${system}.plugin;` with

   ```nix
   src = pkgs.applyPatches {
     name = "nixarchy-menu-snowflake";
     src = inputs.nixarchy-menu.packages.${pkgs.stdenv.hostPlatform.system}.plugin;
     patches = [ ../pkgs/nixarchy-menu/snowflake-button.patch ];
     patchFlags = [ "-p1" "--fuzz=0" ];
     postPatch = ''
       substituteInPlace BarWidget.qml --subst-var-by snowflake \
         ${pkgs.nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png
       grep -q nix-snowflake.png BarWidget.qml
       grep -q 'labelVisible: false' BarWidget.qml
     '';
   };
   ```

   Update the entry's comment by one line to say the button is patched to
   wear the snowflake. → Verify:
   `nix build .#<home-test-attr>` (the attribute `tests/options.nix` uses
   for `menuOnHome`), then `grep nix-snowflake` in the built plugin's
   `BarWidget.qml`. If `applyPatches` on the pinned nixpkgs does not pass
   `patchFlags` through, use `runCommand` with `cp -r` and
   `patch -p1 --fuzz=0` instead, and record the change in that repo's
   plan.
4. `tests/qml.nix`: add the patched `BarWidget.qml` to the lint loop, by
   passing the patched plugin in the same way `panel` is passed. →
   Verify: the check prints `== menu-plugin/BarWidget.qml ... ok`.
5. `tests/options.nix`, next to `menuValidated`: assert that
   `"$menuValidated"`'s `BarWidget.qml` contains `nix-snowflake.png`. →
   Verify: the test fails with the patch reverted and passes with it in
   place.
6. Run `nix flake check` in the nixarchy worktree. Open a PR that links the
   issue, the three documents and nixos_config#2074. Merge it once CI is
   green. If #1052 merged first, rebase before merging.

### nixos_config (this repo, worktree `../nixos-2074`)

1. Run `nix flake update nixarchy` to the merge from step 6, and check
   whether #1052 is included.
   - #1052 not included: put back in `hosts/p620/nixos/nixarchy.nix` and
     `hosts/razer/nixos/nixarchy.nix`:

     ```nix
     # nixarchy-menu as the Omarchy menu (#2019, #2074); nixarchy draws the
     # snowflake on its bar button.
     home-manager.users.olafkfreund.programs.nixarchy.defaultPlugins.menu = true;
     ```

   - #1052 included: leave both hosts unchanged, because the lock bump
     alone brings the menu back.

   → Verify: `just check-syntax`.
2. Run `just test-host p620` and `just test-host razer`. → Verify: both
   build, and the p620 Home Manager activation script mentions
   `nixarchy.menu` again (`grep -c nixarchy.menu` on it, which was 0 after
   #2070).
3. Open a PR that links intent, spec and plan and closes #2074. Merge it
   once CI is green, and return `~/.config/nixos` to `main` with a
   fast-forward.
4. Deploy, after announcing on the agent bus (`#agents`):
    `just quick-deploy p620`, then `just deploy-via-p620 razer`. p510 is
    not deployed.
5. Runtime check on p620 and razer (razer over one batched ssh call).
    - `omarchy plugin list`: `nixarchy.menu enabled`, `omarchy.menu`
      disabled. If `nixarchy.menu` is still disabled, run
      `omarchy plugin enable nixarchy.menu` once.
    - Grep the installed plugin's `BarWidget.qml` for `nix-snowflake.png`.
    - Restart the shell, or ask you to log in again, then take a screenshot
      of the bar's menu slot and confirm the snowflake.
    - `Super+Space` opens the palette, and a running timer shows its
      countdown next to the button.
    - p510 read-only: `omarchy plugin list | grep menu` is unchanged.

## Deviations

- Steps 2–3 (nixarchy): no `.patch` file. nixarchy's
  `pkgs/AGENTS.md#patching-upstream` makes `--replace-fail` the rule, so
  nixarchy#1057 inserts the snowflake with one `substituteInPlace
  --replace-fail` on the button's single `fontFamily: "omarchy"` line. It
  fails the build just as loudly on a reworded anchor. It was approved in
  nixarchy's own spec and plan for #1053.
- Steps 7–11 appear as 1–5 under the nixos_config heading, because the
  Markdown formatter renumbered that list.

## Tests

| Command | Expected |
| ------- | -------- |
| `nix flake check` in the nixarchy worktree | green, including `qml` lint and the options assertions |
| `grep -c nix-snowflake.png <patched plugin>/BarWidget.qml` | 1 |
| `just test-host p620` / `just test-host razer` | build succeeds |
| `omarchy plugin list \| grep menu` on p620 and razer | `nixarchy.menu enabled`, `omarchy.menu disabled` |
| screenshot of the bar | snowflake in the menu slot |

## Rollback

- Hosts: remove the `defaultPlugins.menu = true` lines again (the #2070
  state), or `git revert` this repo's PR, then redeploy p620 and razer.
  nixarchy's activation hands the slot back to `omarchy.menu`. The
  previous generation also works through `nixos-rebuild switch --rollback`.
- nixarchy: `git revert` its PR. The plugin then returns to the unpatched
  source, with the Omarchy mark but a working menu.
