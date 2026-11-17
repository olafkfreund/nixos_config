---
status: approved
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

   Verify (lead), with the override flags from above, for **both** p620 and
   razer:
   - `nix eval --raw` of
     `.#nixosConfigurations.<host>.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src`
     must equal
     `<the same host's ...programs.omateams.package>/share/omateams/plugin`.
     Evaluate both and compare them.
   - If the plugin option is missing (an attribute error), nixarchy's option
     isn't visible to the fork's module. In that case add
     `programs.nixarchy.plugins.omateams.src = "${omateams}/share/omateams/plugin";`
     to the host module, as before, and note the deviation in this plan.

3. **`hosts/common/nixos/omarchy-omaoutlook.nix`: one line.**
   - Replace the `omateams = pkgs.customPkgs.omateams.override { ... };`
     line (`:8`) with
     `omateams = config.home-manager.users.olafkfreund.programs.omateams.package;`.
   - Add a comment: the same omateams the user runs, so Teams links open in
     it.
   - Update the header's "Upgrade by" line only if it mentions omateams.

   Verify (lead), per host:
   - Take the derivation whose `pname` is `omaoutlook` from
     `home-manager.users.olafkfreund.home.packages`.
   - Its `postPatch` string must contain
     `"<the user's programs.omateams.package>/bin/omateams"`.
   - For example:

     ```bash
     nix eval --raw --impure --expr "let c = (builtins.getFlake (toString ./.)).nixosConfigurations.p620.config.home-manager.users.olafkfreund; o = builtins.head (builtins.filter (p: (p.pname or \"\") == \"omaoutlook\") c.home.packages); in if builtins.match \".*\${c.programs.omateams.package}/bin/omateams.*\" o.postPatch != null then \"ok\" else \"MISMATCH\""
     ```

     With the override, use `nix eval` on the flake attribute and the same
     `--override-input` flags instead of `getFlake`. Expect `ok`.
   - Step 5's compiled-binary check is the stronger evidence.

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
   - `git add -A`. It also stages step 4's deleted files; no `git rm` is
     needed.
   - For p620 and razer:
     `nix build .#nixosConfigurations.<host>.config.system.build.toplevel -o result-<host>`.
   - **Closure checks**, run for each host. `pkg` is
     `nix eval --raw .#nixosConfigurations.<host>.config.home-manager.users.olafkfreund.programs.omateams.package`
     (with the same flags), and each check names its expected result:
     1. `nix-store -qR result-<host> | grep -E -- '-omateams-[0-9]'` prints
        exactly one path, and it equals `pkg`.
     2. `ldd $pkg/bin/.omateams-wrapped | grep -o 'qtwebengine-[^/]*' | sort -u`
        prints only `qtwebengine-6.140.0`.
     3. `$pkg/bin/omateams` contains `MemoryHigh=12G`, `MemoryMax=16G`,
        `MemorySwapMax=0`, and a second `exec "$pkg/bin/omateams-unscoped"`
        line for the case with no user bus.
     4. `$pkg/bin/omateams-unscoped` contains the store path of
        `nixosConfigurations.<host>.config.programs.hyprland.package`.
     5. `$pkg/share/applications/omateams.desktop` and
        `$pkg/share/icons/hicolor/scalable/apps/omateams.svg` exist.
     6. `$pkg/share/omateams/plugin/ui/BarWidget.qml` contains
        `(Color.bar && Color.bar.background) || "transparent"`.
     7. `$pkg/share/omateams/plugin/ui/Service.qml` contains
        `checkInstalled()`, has no `ensureHost()` call in
        `Component.onCompleted`, and contains `"$pkg/bin/omateams"`.
     8. `$pkg/share/omateams/plugin/install.sh` does not exist.
     9. omaoutlook's `bin/.omaoutlook-wrapped` holds `$pkg/bin/omateams`,
        as UTF-8 or UTF-16 (search the bytes with python, as the fork's
        version check does).
   - Run the Opus review (a fresh agent given this plan and `git diff`) and
     the Codex review. Fix confirmed findings, then commit, naming the steps.

6. **Lead: after olafkfreund/omateams#2 merges.**
   - `nix flake update omateams`. It adds the input to `flake.lock` against
     the default branch. `--update-input` is deprecated in Nix 2.35.
   - Rerun step 5's builds **and all nine closure checks** without the
     override, since the merged revision can differ from the branch tested.
   - Review the `flake.lock` diff: only the `omateams` node and its follows
     are added. Commit it as
     `chore(flake): lock omateams to the merged flake (#3028)`.
   - Open the PR linking the three artifacts.

7. **Lead: runtime, only with the owner's OK to switch each host.**
   - **p620:**
     1. Restart: `omateams quit`, then let the bar start it, or run
        `omateams --hidden`.
        `readlink -f /proc/$(omateams status | jq .pid)/exe` must equal
        `$pkg/bin/.omateams-wrapped`.
     2. Teams is still signed in, the bar widget shows, and the host is
        hidden.
     3. `omateams status | jq '{captured, overdue}'` shows
        `captured: false` and an `overdue` field. That field exists only
        with the guard.
     4. `systemctl --user show` on the host's scope (find it with
        `systemctl --user status $(omateams status | jq .pid)`) with
        `-p MemoryHigh -p MemoryMax -p MemorySwapMax` shows `12G`, `16G`
        and `0`, in bytes.
     5. Share and stop 3 times. Expect no `eglCreateSync failed` in
        `journalctl --user --since -10min`. Either `hostMemory` stays
        bounded, or a "Teams restarted" notice shows the guard acting; both
        are acceptable.
     6. A Teams link opened from omaoutlook opens in omateams.
     7. Turn `runInBackground` off in the shell UI, run `omateams quit`,
        and reload the shell: the host doesn't start. Then turn it back on.
     8. The plugin stays enabled. If the user had turned it off, the
        enable-once hook would not turn it back on; that is its existing
        behaviour.
   - **razer:** after the switch and a restart, Teams starts, is signed in,
     and shows the bar widget. The running exe is razer's `$pkg`.
   - Report the results in the PR.

## Tests

- Steps 2-4: each step's `nix eval` or grep check.
- Step 5: two host builds and the closure checks.
- Step 7: the runtime list, which needs the owner's OK to switch.

## Rollback

- Before merge: drop the branch.
- After merge: revert the PR, then rebuild. `pkgs/omateams` comes back,
  and the sign-in in `~/.local/share/omateams` is untouched either way.

## Deviations during implementation

- **Closure check 9 (omaoutlook binary) can't be measured.**
  - Qt stores compiled QML compressed in the binary, so the omateams path
    is not in it as plain bytes.
  - The omaoutlook installed before this change fails the same check, so
    this is not a regression.
  - What proves the omaoutlook link instead:
    - step 3's evaluation: omaoutlook's `postPatch` holds the user's
      `programs.omateams.package` path, on both hosts;
    - omaoutlook's own install check, which greps the patched `Main.qml` for
      that path at build time.
- **Existing gap, not changed here.** For the same reason, Nix records no
  store reference from omaoutlook to omateams. It stays safe because the
  same omateams is in the user's closure through `home.packages`.
- **Step 3's check command.** `builtins.match` refuses a pattern that refers
  to a store path. The check strips that reference
  (`builtins.unsafeDiscardStringContext`) and tests with `builtins.split`.
- **Review fixes from step 5.** These come from the Opus review. Codex's one
  finding is the missing `flake.lock` entry, which is step 6 by design.
  - **`.claude/commands/check-updates.md`:** the `pkgs/omateams` row is
    removed. The flake input falls under "Other flake inputs".
  - **`omarchy-omaoutlook.nix` imports `./omarchy-omateams.nix`:** it reads
    the user's `programs.omateams.package` now, so a host importing only
    omaoutlook would otherwise fail to evaluate.
  - **`pkgs/default.nix`:** omaoutlook's default `omateams` is a `throw`
    naming the host module, not `null`, so a bare build says what is
    missing.
