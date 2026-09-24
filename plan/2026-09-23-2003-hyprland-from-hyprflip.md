---
status: approved
issue: 2003
spec: spec/2026-09-23-2003-hyprland-from-hyprflip.md
---

# Plan: p620 and razer run the Hyprland that hyprflip has verified

## Approved decisions

- Trial on **p620 and razer only**. `nixarchy.inputs.hyprland` (`/main`, the
  aquamarine fix) is unchanged, so p510 and nixarchy are untouched.
- Both hosts take their compositor from
  `inputs.hyprflip.inputs.hyprland`, the commit hyprflip's nightly job last
  verified. `nix flake update hyprflip` is their Hyprland update.
- One shared file carries the override and the switch-back steps.
- `omarchy-sole-hyprland.nix` reads `config.programs.hyprland.package`, so the
  profile and wrapper always match the session (the #1566 lesson).
- p620 uses the cached `hyprflip` and `hy3` builds. razer gets the compositor
  only, with no plugins.
- The plugin's commit and ABI checks stay. Switching each live host is a
  separate go-ahead.

## Steps

0. **Baseline** (before editing). Record
   `nix eval --raw .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath`
   for p510, and `config.programs.hyprland.package` for p620 and razer.
   → verify: the values are saved in the scratchpad for steps 6-7.
1. **`hosts/common/nixos/omarchy-sole-hyprland.nix`.** Add `config` to the
   arguments. Replace line 25 with `hyprland = config.programs.hyprland.package;`,
   and change the comment above it to "the host's chosen compositor". Adjust
   the comment at "This must be the Hyprland NIXARCHY pins" to say "the
   Hyprland the session runs (programs.hyprland.package)".
   → verify: p510's drvPath equals the baseline.
2. **New `hosts/common/nixos/hyprland-from-hyprflip.nix`:**

   ```nix
   { lib, pkgs, inputs, ... }:
   # TRIAL since 2026-09-23 (#2003), p620 and razer only: run the Hyprland main
   # commit hyprflip's nightly CI last built and tested (its flake.lock), not
   # nixarchy's tip of main. Compositor and hyprflip plugins then always match
   # and come prebuilt from hyprland.cachix.org / nixarchy.cachix.org.
   # Update with `nix flake update hyprflip`; `update nixarchy` no longer moves
   # these hosts' Hyprland.
   #
   # Switch back:
   #   1. drop this import from hosts/p620/nixos/nixarchy.nix and
   #      hosts/razer/nixos/nixarchy.nix;
   #   2. flake.nix: restore `inputs.hyprland.follows = "nixarchy/hyprland";`
   #      on hyprflip, then `nix flake lock`;
   #   3. p620: delete programs.hyprflip.package / hy3Package;
   #   4. delete this file.
   {
     # mkForce: nixarchy sets this at normal priority and asks for mkForce.
     programs.hyprland.package = lib.mkForce
       inputs.hyprflip.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
   }
   ```

   → verify: `nix-instantiate --parse` succeeds.
3. **`flake.nix`, the `hyprflip` input.** Remove
   `inputs.hyprland.follows = "nixarchy/hyprland";`. Rewrite its comment: the
   plugin keeps its own nightly-verified Hyprland, and p620 and razer run that
   Hyprland (see `hosts/common/nixos/hyprland-from-hyprflip.nix`). Then run
   `nix flake lock`.
   → verify: `jq` on `flake.lock` shows the hyprflip node with its own
   `hyprland` input at the rev in hyprflip's lock, and the nixarchy/hyprland
   node unchanged.
4. **`hosts/p620/nixos/nixarchy.nix`.** Add the import after
   `omarchy-sole-hyprland.nix`. In `programs.hyprflip`, add
   `package = inputs.hyprflip.packages.x86_64-linux.hyprflip;` and
   `hy3Package = inputs.hyprflip.packages.x86_64-linux.hy3;`, with a comment
   saying these are the cached builds, and update the block comment.
5. **`hosts/razer/nixos/nixarchy.nix`.** Add the import after
   `omarchy-sole-hyprland.nix`.
6. **Evaluate.**
   - p510's drvPath equals the baseline.
   - On p620 and razer, `config.programs.hyprland.package`,
     `config.security.wrappers.Hyprland.source` (without `/bin/Hyprland`) and
     the hyprland entry in `environment.systemPackages` all equal hyprflip's
     Hyprland `outPath`.
   - On p620, `environment.etc."hyprflip/hyprflip.so".source` and `libhy3.so`
     start with `inputs.hyprflip.packages.x86_64-linux.{hyprflip,hy3}` outPaths.
   - `nix path-info --store https://nixarchy.cachix.org` finds both.
7. **Build.** Run `nixos-rebuild build --flake .#p620` and `.#razer`. The log
   must show `hyprflip`, `hy3` and `hyprland-0.56` fetched, not built
   (`grep -E "building '.*(hyprflip|hy3|hyprland-0)"` is empty).
8. **Commit and PR.** One `feat:` commit for steps 1-5, then a PR linking the
   intent, spec and plan, with `Closes #2003`. Merge once CI is green.
9. **Live switch (your go-ahead per host).** On p620, run
   `sudo nixos-rebuild switch --flake .#p620`, log out and back in, then check
   `hyprctl version` (commit `e368c13` or the current hyprflip lock),
   `hyprctl hyprflip status` and `hyprctl configerrors`. razer is deployed the
   same way when you say so.

## Tests

Steps 1 and 6 cover p510 staying unchanged and every Hyprland path matching.
Step 7 covers the build and the cache hits. Step 9 covers the running session.

## Rollback

- Live: select the previous generation at boot, or run
  `sudo nixos-rebuild switch --rollback`.
- Code: follow the switch-back steps in the new file's header, or revert the
  PR.
