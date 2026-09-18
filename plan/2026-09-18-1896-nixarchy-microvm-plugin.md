---
status: approved
issue: 1896
spec: spec/2026-09-18-1896-nixarchy-microvm-plugin.md
---

# Plan: install the nixarchy-microvm plugin and its SUPER+ALT+V bind on p620 and razer

## Approved decisions (self-contained summary)

- **Input.** `nixarchy-microvm = { url = "github:olafkfreund/nixarchy-microvm";
  inputs.nixpkgs.follows = "nixpkgs"; }` goes in `flake.nix`, directly after
  the `nixarchy-distrobox` block, with the spec's comment. It tracks `main`.
  The plugin merged there as PR #2 (`481e6c5`), closing issue #1.
- **One new module, `hosts/common/nixos/omarchy-microvm.nix`**, in the shape
  of `omarchy-ai-mirror.nix`. Its header comment gives the two one-time steps
  per machine: the `pcall` line and `omarchy plugin enable`.

  ```nix
  { inputs, ... }:
  {
    home-manager.users.olafkfreund = { pkgs, ... }: {
      imports = [ inputs.nixarchy-microvm.homeManagerModules.default ];
      programs.nixarchy.plugins."nixarchy.microvm".src =
        inputs.nixarchy-microvm.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  }
  ```

  The plugin's module writes `~/.config/hypr/microvm-binds.lua`, with
  `programs.nixarchy-microvm.keybinding` at its default of `SUPER + ALT + V`.
  That chord is free on both hosts.
- **Hosts.** `hosts/p620/nixos/nixarchy.nix` and
  `hosts/razer/nixos/nixarchy.nix` each import
  `../../common/nixos/omarchy-microvm.nix`, after `omarchy-ai-mirror.nix`.
  p510 does not.
- **Left out of the branch:**
  - the `nixarchy-voice` lock bump, which is stashed and restored;
  - the staged `p1` test lines, which must be gone first (precondition 1);
  - the microvm service on razer, which stays off.
- **`bindings.lua` is user-owned.** razer gets exactly the `pcall` block
  p620 already has. Nothing else in it changes.

## Preconditions

1. **`p1` is gone from p620.** `~/.config/nixarchy/{apps,services}.nix` have
   already been restored. The user runs `nixarchy-apply` once more.
   → Verify:
   - `git status --short` in `/etc/nixos` shows no `hosts/p620/nixarchy/*`
     entry;
   - `systemctl list-unit-files 'microvm@*'` is empty;
   - `nixarchy-pkg pending` lists nothing for microvm.
2. **The plugin is on `main`.** Done: `481e6c5`, and CI and Pages passed.

## Steps

Each step cites `plan step N`. The code goes in one commit, `feat: install
nixarchy-microvm plugin and SUPER+ALT+V bind on p620 and razer (#1896)`. A
deviation updates this file in the same commit.

1. **Stash the voice bump.**
   `git stash push -m "pending nixarchy-voice lock bump (not #1896)" -- flake.lock`
   → Verify: `git status --short` shows no `flake.lock`, and `git stash list`
   shows the entry.
2. **`flake.nix`: add the input, then run `nix flake lock`.**
   → Verify: `git diff flake.lock` adds only the `nixarchy-microvm` node and
   the root `inputs` entry, pinned to `481e6c5` or later.
3. **Write `hosts/common/nixos/omarchy-microvm.nix`, and add the two host
   imports.**
   → Verify:
   `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.nixarchy-microvm.keybinding`
   gives `"SUPER + ALT + V"`. The same eval for razer, and the plugin
   attribute set, both list `nixarchy.microvm`.
4. **Build-test:** `just validate`, `just test-host p620` and
   `just test-host razer`. Also compare p510's toplevel `drvPath` before and
   after.
   → Verify: all three build, and p510's `drvPath` is unchanged.
5. **Commit and push, then open a PR** that links the three artifacts and
   closes #1896.
   → Verify: the pre-commit hooks pass and CI starts.
6. **p620 rollout.**
   1. Move `~/.config/omarchy/plugins/nixarchy.microvm` and
      `~/.config/hypr/microvm-binds.lua` into the task scratchpad.
   2. Run `just p620`.

   → Verify:
   - `readlink -f` on both paths gives `/nix/store/…` paths;
   - `hyprctl reload`, then `hyprctl binds -j` has exactly one modmask-72
     `V` bind, described "MicroVMs";
   - Super+K's records list `SUPER ALT + V → MicroVMs`;
   - after `omarchy-restart-shell`, `omarchy shell nixarchy.microvm.bar
     status` answers;
   - `qs log` is clean.

   **If the switch fails:** move both back, then `hyprctl reload` and
   `omarchy-restart-shell`.
7. **razer rollout.**
   1. Run `just deploy-via-p620 razer`.
   2. Over SSH:
      - `omarchy plugin enable nixarchy.microvm`;
      - append the `pcall(require, "hypr.microvm-binds")` block to
        `~/.config/hypr/bindings.lua`, after backing it up to
        `bindings.lua.bak-1896`;
      - `hyprctl reload` and `omarchy-restart-shell`, with
        `HYPRLAND_INSTANCE_SIGNATURE` taken from `/run/user/<uid>/hypr/`.

   → Verify, over SSH:
   - the plugin directory and `microvm-binds.lua` are store links;
   - one SUPER+ALT+V "MicroVMs" bind;
   - `hyprctl configerrors` is empty;
   - `status` returns JSON;
   - `omarchy-shell shell toggle nixarchy.microvm '{}'` puts
     `nixarchy-microvm-menu` in `hyprctl layers -j`, then toggle again to
     close.
8. **Restore the stash:** `git stash pop`.
   → Verify: the voice bump is back as an uncommitted change, and the stash
   list is empty. **If the pop conflicts:** leave the stash in place, and
   report it.
9. **Merge.** Once CI is green, merge the PR.
   → Verify: the PR is merged and #1896 is closed.

Before steps 6 and 7, announce on the agent bus (`#agents:freundcloud.org.uk`)
after reading it. The deploy guard requires it.

## Tests

- **A. Evaluation and build:** step 3's evals, `just validate`, both
  `just test-host` runs, and p510's `drvPath` unchanged.
- **B. Live on p620:**
  - the two store links;
  - one bind, which Super+K lists;
  - `status` answering;
  - a clean `qs log`.
- **C. Live on razer, over SSH:**
  - the two store links;
  - enabled;
  - the bind, with no config errors;
  - `status` JSON;
  - the menu layer opening and closing.
- **D. Repository hygiene:** the committed diff touches exactly `flake.nix`,
  `flake.lock`, the new module and the two host files. The voice bump is
  back as an uncommitted change.

## Rollback

- **Before merge:** close the PR, delete the branch, and `git stash pop` if
  the stash is still held.
- **After merge:** `git revert` the merge commit, `just p620`, and
  `just deploy-via-p620 razer`. Home Manager removes the store links. The
  `pcall` line is harmless without the file, so it can stay or be removed
  (razer has `bindings.lua.bak-1896`). `omarchy plugin disable
  nixarchy.microvm` on each host takes the widget off the bar.
- **p620's hand copies** stay in the scratchpad until step 6 passes, and can
  be moved back.

## Implementation record

### Deviations

### Test results
