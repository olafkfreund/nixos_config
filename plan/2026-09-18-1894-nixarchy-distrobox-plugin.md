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
2. **Step 7: razer needed no shell restart, and could not have one.**
   - Over SSH, the `omarchy-shell` wrapper pointed at the new tree while the
     running shell was on the pre-deploy tree. Quickshell finds its instance
     by config path, so every call said "not running".
   - The session's own `OMARCHY_PATH` (from
     `systemctl --user show-environment`, as `omarchy-restart-shell` does)
     reached it. `omarchy plugin enable` hot-loaded the plugin into the
     running shell.
   - A restart was then refused, correctly, because the session had
     idle-locked; forcing it would strand the lock screen. It was no longer
     needed.
3. **Step 7: a leftover menu layer on razer, not yet explained with
   certainty.**
   - After opening and closing the menu over SSH, `hyprctl layers` still
     lists one `nixarchy-distrobox-menu` layer, with **`pid: -1`**. The plugin
     reports itself closed (`views: 0` from the bar and from the menu), and
     `shell hide` changes nothing.
   - razer's only output is DPMS-off.
   - On p620, with a lit display, a live layer carries its real pid and is
     gone within 50 ms of closing.
   - Reading: a surface the client already destroyed, kept by Hyprland until
     the output renders a frame (`grim` over SSH hung on razer the same way).
   - **Unverified until razer's screen wakes;** it was not woken remotely.
4. **The pending lock bump was mislabelled, and building from the stashed
   tree reverted it on p620.**
   - The uncommitted `flake.lock` change is a bump of **`nixarchy-voice`**
     (d8340f9 → 481d3f3), not `nixarchy-pkg` as the intent, spec and this
     plan say. A `git diff -U12` grep picked up a neighbouring node's name.
   - It belongs to another agent, `p620-7880d9`, who had already switched
     p620 from the dirty tree at 17:45.
   - Step 6 stashed it correctly for the commits, but then built p620 from the
     stashed tree, which switched the live nixarchy-voice back to d8340f9.
   - Found by reading the agent bus in full. After step 8 restored the stash,
     p620 was re-switched from the tree (`s78gqz3l…`).
     `omarchy-voice.service` runs `ciz5ma6g…-omarchy-voice-0.3.0` again, the
     plugin link is intact, and there are 0 failed units. Posted on the bus to
     that agent.
   - razer never had the bump.
   - The lesson: stashing keeps a change out of a commit, but also out of any
     system built from the tree. Compare `/run/current-system` with the tree
     before switching from a stashed tree.

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
- **Step 5:** PR #1895 is open, and the hooks pass.
- **Step 6 (p620):**
  - Announced on the agent bus, then backed up the development copy (12
    files) and removed it. `just p620` exit 0.
  - `readlink -f` → `/nix/store/32rlhics…-nixarchy-distrobox-0.1.0`.
  - `status` answers on 3 bars without being enabled again. No plugin errors
    in `qs log`, 0 failed units, and the cube glyph is on the bar.
  - Later re-switched for deviation 4.
- **Step 7 (razer):**
  - NVIDIA module and userspace were both 610.57.04 before the deploy.
    `just deploy-via-p620 razer` exit 0.
  - Store link as on p620. Enabled (`[{"id":"nixarchy.distrobox"}]`).
  - `status` lists razer's real boxes `["Fedora","Debian"]`.
  - The menu opened (live pid), and 0 failed units. The close left the layer
    in deviation 3.
- **Step 8:** `git stash pop` was clean. The `nixarchy-voice` bump is back,
  uncommitted, and the stash list is empty.
