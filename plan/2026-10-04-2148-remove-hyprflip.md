---
status: approved
issue: 2148
spec: spec/2026-10-04-2148-remove-hyprflip.md
---

# Plan: remove hyprflip from p620 and razer

Already executed as the incident fix (PR #2149, squash 5ab2d61d9). This plan
records the steps as they ran.

Summary of the decisions: remove the hyprflip and omacards flake inputs and
both hyprflip host fragments, so p620 and razer fall back to nixarchy's
Hyprland. That build comes from our nixpkgs, so its glibc matches the system
mesa. The lock may only lose nodes, p510 is not touched, and deploys are
announced on the agent bus first.

## Steps

1. Create a worktree from `origin/main`
   (`git worktree add ../nixos-<issue> -b <branch> origin/main`). Never check
   out a branch in `~/.config/nixos`, which is `/etc/nixos`.
   → verify `git worktree list`.
   Traps: none.

2. `git rm hosts/common/nixos/hyprland-from-hyprflip.nix
   hosts/common/nixos/omarchy-hyprflip.nix`.
   → verify both files are gone.
   Traps: none.

3. `flake.nix`: delete from the `# Hyprflip — two windows …` comment through
   the closing `};` of the `omacards` input, up to the
   `# Oma, voice control` block.
   → verify `grep -n 'hyprflip\|omacards' flake.nix` is empty.
   Traps: none.

4. `hosts/p620/nixos/nixarchy.nix`:
   - drop `../../common/nixos/hyprland-from-hyprflip.nix # trial, #2003`,
     `inputs.hyprflip.nixosModules.default` and
     `../../common/nixos/omarchy-hyprflip.nix` from `imports`;
   - drop the `# Hyprflip plugin + hy3 provider …` comment and the
     `programs.hyprflip = { … };` block;
   - reword the `portalPackage` comment so it no longer mentions
     `hyprland-from-hyprflip.nix`.

   `hosts/razer/nixos/nixarchy.nix`: drop the
   `hyprland-from-hyprflip.nix` import and reword the same comment.

   `hosts/common/nixos/omarchy-sole-hyprland.nix` (line ~25): change the
   comment to "chose as programs.hyprland.package (nixarchy's)".
   → verify `grep -rn -i 'hyprflip\|omacards\|hy3' flake.nix hosts modules home Users`
   is empty.
   Traps: comment density should match the surrounding code; don't add
   narration.

5. `nix flake lock`.
   → verify the output shows only `Removed input` lines, and that no new
   rev appears:

   ```bash
   revs() { jq -r '.nodes[].locked.rev // empty' | sort -u; }
   comm -13 <(git show HEAD:flake.lock | revs) <(revs < flake.lock)  # empty
   ```

   Traps: a bulk `nix flake update` here would move unrelated inputs, so
   use `lock` only.

6. `just test-host p620` and `just test-host razer`.
   → verify both build. Check
   `nix eval --raw .#nixosConfigurations.p620.config.programs.hyprland.package.outPath`,
   then `ldd <that>/bin/.Hyprland-wrapped | grep libc.so` shows glibc 2.44, and
   `nix-store -qR result | grep -i hyprflip` is empty (hash substrings such
   as `…hy3…` in unrelated paths are false positives).
   Traps: none.

7. Commit `fix(desktop): remove hyprflip from p620 and razer (#2148)`, with
   the message passed through `git commit -F <file>`.
   Traps: the bus guard greps command text for words like restart/deploy,
   so put prose in a file. No backticks inside `-m`.

8. Read the agent bus `#agents:freundcloud.org.uk`, post the p620 switch,
   then activate the verified build:
   `sudo nix-env -p /nix/var/nix/profiles/system --set <result>` and
   `sudo <result>/bin/switch-to-configuration switch`, with
   `AGENT_BUS_ANNOUNCED=1`. Then restart `display-manager`, because
   switch does not restart it.
   → verify `loginctl list-sessions` shows a `greeter` session on seat0, the
   `sddm` user's Hyprland is still running after 5 s, and there is no new
   "Hyprland has crashed" line in the journal.
   Traps: before touching the checkout, check that no `nhs` is running
   (`pgrep -af 'update-commit-deploy|nh os'`).

9. Push, open the PR, squash-merge it, then `git pull --ff-only` in
   `~/.config/nixos` and confirm `origin/main` lacks
   `hosts/common/nixos/hyprland-from-hyprflip.nix`.
   Traps: an `nhs` lock-bump squash can replace a just-merged commit, so
   check the tree, not the PR badge.

10. Post the razer deploy on the bus, then from `~/.config/nixos` on main
    run `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`.
    → verify over one `ssh razer` call: `/run/current-system` is the built
    path, `systemctl --failed` is empty, `/etc/hyprflip` is absent, and the
    Hyprland in use links glibc 2.44.
    Traps: razer exit 4 from the syncthing-init race is cosmetic. p510 is
    not deployed.

## Tests

- `just test-host p620` and `just test-host razer`: both build.
- `ldd …/.Hyprland-wrapped | grep libc.so`: `glibc-2.44-25`.
- p620 greeter: Hyprland running, `journalctl -b --since -60s | grep -c 'Hyprland has crashed'` returns 0.
- razer: built path active, no failed units.

## Rollback

`git revert 5ab2d61d9` on a branch, merge, then
`nix flake lock` (this restores the hyprflip and omacards inputs at their
previous revs) and deploy p620 and razer. That restores the glibc mismatch,
so it is only useful together with the `nixpkgs` follows from the rejected
alternative. Don't roll back to the previous system generation: that is
the hyprflip build that cannot start Hyprland.
