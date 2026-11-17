---
status: draft
issue: 3028
spec: spec/2026-11-17-3028-omateams-flake.md
coders:
  1: coder   # one flake input with a comment, mechanical
  2: codex   # the host module rewrite: home-manager import inside a NixOS module, easy to get subtly wrong
  3: coder   # one line in omarchy-omaoutlook.nix
  4: coder   # delete pkgs/omateams, two lines in pkgs/default.nix
reviewers:
  - codex    # independent read of the diff against this plan, beside the Opus review
---

# Plan: Install omateams from the olafkfreund/omateams flake

## Approved decisions (from the spec)

- **Input.** Add `omateams = { url = "github:olafkfreund/omateams"; inputs.nixpkgs.follows = "nixpkgs"; inputs.home-manager.follows = "home-manager"; }`.
  - It tracks the default branch; `flake.lock` pins the commit.
  - `nixpkgs-qt` is **not** followed: it carries QtWebEngine 6.140.0, the
    QTBUG-142040 fix, and the fork's build refuses an older Qt.
- **Host module.** `omarchy-omateams.nix` imports
  `inputs.omateams.homeManagerModules.default` for olafkfreund. It sets
  `programs.omateams = { enable = true; package = <fork package>.override { hyprland = config.programs.hyprland.package; }; }`
  and keeps `local.omarchy.enableOnce = [ "omateams" ]`. The module sets
  `home.packages` and `programs.nixarchy.plugins.omateams.src`.
- **omaoutlook.** It takes
  `config.home-manager.users.olafkfreund.programs.omateams.package`.
- **Removals.** `pkgs/omateams/` goes. In `pkgs/default.nix` the
  `omateams` line goes, and `omaoutlook` gets `{ omateams = null; }`.
- **Before olafkfreund/omateams#2 merges,** every eval and build uses
  `--override-input omateams github:olafkfreund/omateams/feat/nix-flake --no-write-lock-file`.
  The fork's default branch has no `flake.nix` yet, so `flake.lock` is
  written only after #2 merges. This PR merges after that.
- **After a switch the old host keeps running,** because both are 1.4.1, so
  runtime verification restarts omateams explicitly. Bumping the fork's
  manifest is out of scope.

## Repo traps (apply to every step)

- **Where to work.** Only in the worktree `~/.config/nixos-3028`
  (`feat/3028-omateams-flake`), never in `~/.config/nixos` or on `main`.
- **Commit hooks.** Pre-commit runs the formatters. Implementers don't
  commit; the lead does, and fixes anything the formatter changes.
- **No host deploys by implementers.** No `switch`, `boot` or `test` on any
  host. Builds use `nix build` of `config.system.build.toplevel`, run by the
  lead. p510 is not involved; never build or deploy it.
- **Git and flakes.** A flake only sees files tracked by git. A deleted
  directory must be `git rm`ed, and that is the lead's job.

## Steps

1. **`flake.nix`: the input.** Put it after the `omapod` input (around
   `:150-155`), with this comment:

   ```nix
   # omateams: Microsoft Teams web in an Omarchy-themed window, from our fork;
   # hosts/common/nixos/omarchy-omateams.nix (#3028). nixpkgs-qt is not followed:
   # it pins QtWebEngine 6.140.0 (QTBUG-142040) until our nixpkgs has it.
   omateams = {
     url = "github:olafkfreund/omateams";
     inputs.nixpkgs.follows = "nixpkgs";
     inputs.home-manager.follows = "home-manager";
   };
   ```

   - The `outputs` function takes `inputs@{ ... }` or `...`. Confirm that
     `omateams` reaches `inputs` without another change.

   Verify: `nix-instantiate --parse flake.nix`.

2. **`hosts/common/nixos/omarchy-omateams.nix`: the rewrite.** The whole
   file becomes:

   ```nix
   # Omateams: Microsoft Teams web in an Omarchy-themed window (#2505, #3028),
   # from our fork's flake. Its home-manager module installs it and registers
   # the plugin; the plugin is enabled once per host by the shared post-boot
   # hook. Sign in to Teams once per host: the login lives in
   # ~/.local/share/omateams and stays yours.
   # Update with `nix flake update omateams`, never `omarchy plugin update`.
   { config, inputs, pkgs, ... }:
   let
     # The fork's package, with the host's Hyprland tools on its PATH.
     omateams = inputs.omateams.packages.${pkgs.stdenv.hostPlatform.system}.omateams.override {
       hyprland = config.programs.hyprland.package;
     };
   in
   {
     imports = [ ./omarchy-enable-once.nix ];

     home-manager.users.olafkfreund = {
       imports = [ inputs.omateams.homeManagerModules.default ];
       programs.omateams = {
         enable = true;
         package = omateams;
       };
       local.omarchy.enableOnce = [ "omateams" ];
     };
   }
   ```

   Verify (lead), with the override flags from above:
   `nix eval --raw` of
   `.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src`.
   It ends in `/share/omateams/plugin`, and the store path is the fork's
   package.

3. **`hosts/common/nixos/omarchy-omaoutlook.nix`: one line.**
   - Replace the `omateams = pkgs.customPkgs.omateams.override { ... };`
     line (`:8`) with
     `omateams = config.home-manager.users.olafkfreund.programs.omateams.package;`.
   - Add a comment: the same omateams the user runs, so Teams links open in
     it.
   - Update the header's "Upgrade by" line only if it mentions omateams.

   Verify (lead): `nix eval` of omaoutlook's `omateams` argument (through
   `home-manager.users.olafkfreund.home.packages`) equals the user's
   `programs.omateams.package`.

4. **`pkgs/`: remove the local package.**
   - Delete `pkgs/omateams/`.
   - In `pkgs/default.nix`, remove the `omateams = ...` line and its comment
     (`:55-56`).
   - Change `:59` to
     `omaoutlook = pkgs.callPackage ./omaoutlook { omateams = null; }; # omateams comes from hosts/common/nixos/omarchy-omaoutlook.nix`.

   Verify:

   ```bash
   test ! -e pkgs/omateams
   grep -rn --include='*.nix' -e 'customPkgs.omateams' -e 'pkgs/omateams' -e './omateams' .
   ```

   The grep must print nothing.

5. **Lead: build and check, with the override flags.**
   - `git add -A` and `git rm -r pkgs/omateams`.
   - For p620 and razer:
     `nix build .#nixosConfigurations.<host>.config.system.build.toplevel -o result-<host>`.
   - For each host, run every closure check in the spec's Verification
     section:
     - one omateams, and it is the fork's;
     - `ldd` of `.omateams-wrapped` shows only `qtwebengine-6.140.0`;
     - all three memory properties and the unscoped fallback in the wrapper;
     - the host's Hyprland store path in the Qt wrapper;
     - the desktop entry and icon;
     - the `BarWidget` fallback, `checkInstalled()`, and the store binary
       path in `Service.qml`;
     - no `install.sh`;
     - omaoutlook's binary holds the omateams path, as UTF-8 or UTF-16.
   - Run the Opus review (a fresh agent given this plan and `git diff`) and
     the Codex review. Fix confirmed findings, then commit, naming the steps.

6. **Lead: after olafkfreund/omateams#2 merges.**
   - `nix flake lock --update-input omateams`, which writes `flake.lock`
     against the default branch.
   - Rerun step 5's builds without the override.
   - Open the PR linking the three artifacts.

7. **Lead: runtime, only with the owner's OK to switch each host.**
   - The spec's runtime list for p620: items 1-8, starting with the
     explicit restart and the running exe's store path.
   - The razer check.
   - Report the results in the PR.

## Tests

- Steps 2-4: each step's `nix eval` or grep check.
- Step 5: two host builds and the closure checks.
- Step 7: the runtime list, which needs the owner's OK to switch.

## Rollback

- Before merge: drop the branch.
- After merge: revert the PR, then rebuild. `pkgs/omateams` comes back,
  and the sign-in in `~/.local/share/omateams` is untouched either way.
