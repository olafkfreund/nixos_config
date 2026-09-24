---
status: approved
issue: 2019
spec: spec/2026-09-24-2019-nixarchy-menu-razer-p620.md
---

# Plan: nixarchy-menu as the menu on razer and p620

## The approved decisions, carried over

1. **One PR, one lock bump:** run `nix flake update nixarchy`, which moves
   a5460e2 → **8333f23**, the nine commits listed in the spec. It pulls in
   nixarchy's new `nixarchy-menu` node, which follows nixarchy's own nixpkgs
   and omarchy. Nothing else in the lock moves.
2. **One line per host,** next to `programs.nixarchy.user`, in
   `hosts/razer/nixos/nixarchy.nix` and `hosts/p620/nixos/nixarchy.nix`:

   ```nix
   # nixarchy-menu as the Omarchy menu (#2019, nixarchy#946). Remove to go back
   # to the stock menu at the next login.
   home-manager.users.olafkfreund.programs.nixarchy.defaultPlugins.menu = true;
   ```

3. **razer's hand-copied `~/.config/omarchy/plugins/nixarchy.menu`** is moved
   to `~/dev/nixarchy-menu-hand-copy.bak` during the razer deploy. It is a
   backup, not a delete. p620 has none.
4. **Order:** razer first, then p620, each with the user's go-ahead. p510 is
   not touched.
5. **Deploys run from a fresh worktree of merged `main`.** The recipes build
   `.#<host>` from the current directory, and `~/.config/nixos` has an
   unrelated staged change, so it is never used for this.

## Steps

1. **`flake.lock`:** in the branch worktree, run `nix flake update nixarchy`.
   → Verify:
   - `jq .nodes.nixarchy.locked.rev` is `8333f23…`.
   - `git diff flake.lock` shows only the `nixarchy` node and the new
     `nixarchy-menu` node (plus its `nixarchy-menu` sub-reference).
   - There is no new `nixpkgs_N`.
2. **The two host files:** add the decision-2 line to each.
   → Verify: `grep -n defaultPlugins.menu hosts/*/nixos/nixarchy.nix` shows
   exactly two hits, razer and p620.
3. **Build both hosts:** run `just validate`, `just test-host razer` and
   `just test-host p620` on p620, with no deploy.
   → Verify: all exit 0. Record the razer and p620 toplevel paths here.
4. **PR:** push the branch and open a PR that links the intent, spec and plan
   and closes #2019.
   → Verify: CI is green, then merge with the user's go-ahead.
5. **Deploy razer.**
   - Re-read the bus, claim razer, and hold if another claim is open (53759c
     has a herdr deploy queued from the same nixarchy main).
   - From a fresh worktree of merged `main`, run `just deploy-via-p620 razer`.
   - Then on razer:
     - `mv` the hand copy to the backup
     - `sudo systemctl restart home-manager-olafkfreund`
     - run the default-plugins hook in the session environment, as the next
       login would

   → Verify:
   - The plugin path is a `/nix/store` link.
   - `nixarchy.menu` is enabled; `omarchy.menu` and `evindor.keystroke` are
     disabled.
   - The menu button is in the same slot (screenshots before and after).
   - `omarchy-menu toggle root` opens nixarchy-menu.
   - Exactly one new generation, and 0 failed units.

   Post "done" on the bus.
6. **Deploy p620,** only with the user's go-ahead after step 5.
   - From the same fresh `main` worktree, run `just p620`.
   - Then run the default-plugins hook, or log in again.

   → Verify: the same checks as step 5, where "before" is the stock menu
   button's slot. 0 failed units.
7. **Record** the results of steps 3, 5 and 6 here. Close #2019 through the
   PR. Tick nixarchy-menu's epic #6.

## Tests

- `just validate`, `just test-host razer` and `just test-host p620` all exit
  0, and the PR's CI is green.
- The live checks in steps 5 and 6.

## Rollback

- **Per host:** `sudo nixos-rebuild switch --rollback`, run on that host or
  over ssh for razer. The previous generation has no declared menu. At the
  next login nixarchy's hook restores the stock `omarchy.menu` (nixarchy#946,
  amendment 1).
- **Whole change:** revert the PR.
- **razer's hand copy** can go back from `~/dev/nixarchy-menu-hand-copy.bak`
  if wanted.

## Results

- **Step 1:** nixarchy a5460e2 → 8333f23. The `nixarchy-menu` node (8775661)
  follows `nixarchy/nixpkgs` and `nixarchy/omarchy`. The `nixpkgs_N` count is
  unchanged at 10. The nested `nixarchy/nixarchy-plugin-browser` input moved
  too, as nixarchy's own pin did (82b144a).
- **Step 2:** `defaultPlugins.menu = true` at `hosts/razer/nixos/nixarchy.nix:51`
  and `hosts/p620/nixos/nixarchy.nix:65`.
- **Step 3:** `just test-host razer` and `just test-host p620` both exit 0:
  - razer `li6lbbs2…-nixos-system-razer`
  - p620 `jdy5gbwz…-nixos-system-p620`

  `just validate` fails **only** on nixpkgs-fmt in nine files this change
  doesn't touch (`hosts/{p510,razer,p620}/nixarchy/{apps,advanced,services}.nix`).
  That is pre-existing on main: `git diff origin/main` touches none of them.
- **Step 4:** PR #2021 was merged as ce3014c64 with all seven CI checks
  green, including check-configurations for razer, p620 and p510. It sits on
  top of #2020 (6a75d72f7), which had already put nixarchy on the same
  8333f23.
- **Step 5 (razer, 2026-09-25):** `just deploy-via-p620 razer` from a fresh
  `main` worktree gave **generation 2957** = `li6lbbs2…`, the same toplevel
  as step 3. razer had been on flatsnap's test generation 2956; the user
  confirmed that check was over, and its owner cleaned up its own leftovers.
  - HM logged "your own directory, not replacing it". The hand copy was moved
    to `~/dev/nixarchy-menu-hand-copy.bak`, then HM was restarted, which
    placed the link (`gh2g5346…-nixarchy-menu`).
  - The hook enabled it, and the marker is `omarchy.menu`.
  - Result: `nixarchy.menu` is enabled; `omarchy.menu` and
    `evindor.keystroke` are disabled. The left section is
    `[nixarchy.menu, omarchy.workspaces]` (the same slot), and
    `omarchy-menu toggle root` opens nixarchy-menu. 0 failed units (system
    and user), and one shell.
- **Step 6 (p620):** `just p620` gave **generation 2647** = `jdy5gbwz…`, the
  same toplevel as step 3. HM placed the link.
  - A shell restart run from an agent's non-desktop shell killed the shell
    and the relaunch didn't survive, so p620 had no bar for about 2 min until
    `hyprctl dispatch 'hl.dsp.exec_cmd("omarchy-launch-shell")'`.
  - The hook then enabled the menu, and the marker is `omarchy.menu`.
  - Result: the stock Omarchy logo in the leftmost slot is replaced by
    nixarchy-menu in the same slot, and the rest of the bar is unchanged.
    `omarchy.menu` is disabled, and `omarchy-menu toggle root` opens
    nixarchy-menu. 0 failed units (system and user), and one shell.
- **Step 7:** #2019 was closed by the PR.
