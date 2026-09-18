---
status: approved
issue: 1894
spec: spec/2026-09-18-1894-nixarchy-distrobox-plugin.md
---

# Plan: install the nixarchy-distrobox plugin on p620 and razer

## Approved decisions (self-contained summary)

- **The input.** Add `nixarchy-distrobox = { url =
  "github:olafkfreund/nixarchy-distrobox"; inputs.nixpkgs.follows =
  "nixpkgs"; }` directly after the `nixarchy-pkg` block in `flake.nix`, with a
  comment in the same shape: what it is, and that enabling is one
  `omarchy plugin enable nixarchy.distrobox` per machine.
- **The hosts.** In `hosts/p620/nixos/nixarchy.nix` and
  `hosts/razer/nixos/nixarchy.nix`, directly after the
  `programs.nixarchy.plugins."nixarchy.pkg"` line, add:

  ```nix
  programs.nixarchy.plugins."nixarchy.distrobox".src =
    inputs.nixarchy-distrobox.packages.${pkgs.stdenv.hostPlatform.system}.default;
  ```

  Its comment names the free `SUPER+ALT+D` chord. No keybind is added.
- **Not enabled in Nix.** `shell.json` is runtime state. razer is enabled
  over SSH after its deploy. p620 is already enabled.
- **Not p510.**
- **The pending `flake.lock` bump of `nixarchy-pkg`** is someone else's
  uncommitted change. It is stashed before `flake.lock` is touched, never
  committed here, and restored at the end.
- **Rollout order:**
  1. Build-test both hosts.
  2. p620: back up and remove the hand-copied plugin directory, then
     `just p620`, then verify the store link.
  3. razer: `just deploy-via-p620 razer`, then enable over SSH, then restart
     its shell.
  4. Restore the stash.
- **Environment.** Passwordless sudo on p620 and on razer (checked), so every
  step runs without a prompt.

## Steps

Each step cites `plan step N`. Code goes in one commit, `feat: install
nixarchy-distrobox plugin on p620 and razer (#1894)`. A deviation updates this
file in the same commit.

1. **Stash the pending lock bump.**
   `git stash push -m "pending nixarchy-pkg lock bump (not #1894)" -- flake.lock`
   → Verify: `git status --short` is clean, and `git stash list` shows the
   entry.
2. **`flake.nix`: add the input, then `nix flake lock`.**
   → Verify: `git diff flake.lock` adds only the `nixarchy-distrobox` node and
   the root `inputs` entry, pinned to `7e2a532` or later; no other node
   changes.
3. **Both host files: add the plugin line.**
   → Verify: `nix eval .#nixosConfigurations.{p620,razer}.config.home-manager.users.olafkfreund.programs.nixarchy.plugins`
   lists `nixarchy.distrobox`, or the equivalent attribute path, found with
   the first eval.
4. **Build-test:** `just validate`, `just test-host p620`,
   `just test-host razer`. Also compare p510's toplevel `drvPath` before and
   after.
   → Verify: all build, and p510's `drvPath` is unchanged.
5. **Commit and push, then open a PR** that links the three artifacts and
   closes #1894.
   → Verify: the pre-commit hooks pass and CI starts.
6. **p620 rollout.**
   1. Copy `~/.config/omarchy/plugins/nixarchy.distrobox` to the task
      scratchpad.
   2. Remove the directory.
   3. Run `just p620`.

   → Verify:
   - `readlink -f ~/.config/omarchy/plugins/nixarchy.distrobox` is a
     `/nix/store/…-nixarchy-distrobox-0.1.0` path;
   - after `omarchy-restart-shell`, `omarchy shell nixarchy.distrobox.bar
     status` answers;
   - `qs log` has no plugin errors;
   - the glyph shows (a cropped `grim` of the bar).

   **If the switch fails:** copy the backup back, and `omarchy-restart-shell`.
7. **razer rollout.** `just deploy-via-p620 razer`, then over SSH:
   `omarchy plugin enable nixarchy.distrobox` and `omarchy-restart-shell`.
   → Verify, over SSH:
   - `readlink -f` gives the store path;
   - `omarchy shell nixarchy.distrobox.bar status` returns JSON;
   - `omarchy-shell shell toggle nixarchy.distrobox '{}'` puts
     `nixarchy-distrobox-menu` in `hyprctl layers -j`, then toggle again to
     close.
8. **Restore the stash:** `git stash pop`.
   → Verify: `flake.lock` shows the pending bump again as uncommitted, and the
   stash list is empty. **If the pop conflicts:** leave the stash in place,
   and report it.
9. **Merge.** Once CI is green, merge the PR.
   → Verify: the PR is merged and the issue is closed.

## Tests

- **A. Evaluation and build:** `just validate`, both `just test-host`
  commands, and p510's `drvPath` unchanged.
- **B. Live on p620:** the store link, `status` answering, no QML errors, the
  glyph on the bar.
- **C. Live on razer (SSH):** the store link, enabled, `status` JSON, the menu
  layer opening and closing.
- **D. Repository hygiene:** the committed diff touches exactly `flake.nix`,
  `flake.lock` and the two host files, and the pending bump is back as an
  uncommitted change.

## Rollback

- **Before merge:** close the PR, and delete the branch.
- **After merge:** `git revert` the merge commit, then `just p620` and
  `just deploy-via-p620 razer`.
- **Either way:**
  - `omarchy plugin disable nixarchy.distrobox` on razer if wanted;
  - on p620, the scratchpad copy can be put back as a real directory if the
    Nix link is not wanted.
- **The rebuild:** each host's previous generation stays bootable, and
  `sudo nixos-rebuild switch --rollback` undoes a switch.

## Implementation record

### Deviations

1. **`just validate` fails on formatting in files this task does not touch.**
   `nixpkgs-fmt` flags nine `hosts/{p510,p620,razer}/nixarchy/{apps,services,
   advanced}.nix` files, which `nixarchy-apply` generates and which were last
   changed on `main` in `9415fac5c`. This task's three Nix files pass
   `nixpkgs-fmt --check` (0 / 3). They are left alone here, because
   reformatting generated files is out of scope and `nixarchy-apply` would
   rewrite them. Worth a separate issue.

### Test results

- **Step 1:** the pending `nixarchy-pkg` lock bump is stashed, and the tree is
  clean.
- **Step 2:** the lock diff is additions only: the `nixarchy-distrobox` node,
  pinned to `7e2a532`, and its root entry.
- **Step 3:** `nix eval` of `programs.nixarchy.plugins` on p620 and razer
  lists `nixarchy.distrobox` →
  `/nix/store/32rlhics…-nixarchy-distrobox-0.1.0`.
- **Step 4:** `just test-host p620` and `just test-host razer` build. p510's
  toplevel `drvPath` is unchanged (`qwn3s3ib…-nixos-system-p510`).
  `just validate`: see deviation 1.
