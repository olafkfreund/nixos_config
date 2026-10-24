---
status: approved
issue: 2465
spec: spec/2026-10-24-2465-nixi-companion.md
---

# Plan: nixi's snowflake companion runs on p620 and razer

The approved decisions:

- Set `companion.enable = true;` in each host's Home Manager `services.nixi`
  block.
- Run `nix flake update nixarchy` to an edge that contains nixarchy #1438.
- Build both hosts. Deploy from `main` after merging: p620 with no CI in
  flight and announced on the bus, razer built on p620.

## Steps

1. `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`: in
   `services.nixi = {`, after `omarchyHooks.enable = true;`, add
   ```nix
         # The snowflake desktop companion (SUPER+ALT+S); nixarchy supplies the package.
         companion.enable = true;
   ```
   → verify: `nix fmt`, then `git diff --stat` shows these 2 files.
2. `flake.lock`: run `nix flake update nixarchy`.
   → verify: the nixarchy node's `rev` is an edge commit, and
     `git -C /mnt/code/Source-home/nixarchy merge-base --is-ancestor 0ca68d97 <rev>`
     succeeds.
3. Evaluate the option for both hosts → `true`.
4. **Build both toplevels** (a p620 system build is the heavy tier): run it
   only when nixarchy's `vm-host-free.sh install|edge` both print `free` and
   the load is below 12.
   → verify that both builds are green.
5. **The PR and the merge.** Fill in the template and link the intent, spec
   and plan. Merge once its CI is green.
6. **Deploy from `main`.**
   - Wait until `gh -R olafkfreund/nixarchy run list` shows no install
     queued or running.
   - Announce on the bus, then run `AGENT_BUS_ANNOUNCED=1 just quick-deploy p620`.
   - Then `just deploy-via-p620 razer`.

   → verify that `command -v nixi-companion` works on both hosts, and that
     the hook file exists.

## Deviations

- **The setting is a shared module** with keybindings, instead of a line in
  each host. The owner asked for it fast, and a second session's p620 branch
  had the companion's SUPER+ALT+S / SUPER+ALT+SHIFT+S binds, which the
  companion needs to be reachable.
  - `hosts/common/nixos/omarchy-nixi-companion.nix` follows
    `omarchy-gog.nix`'s pattern. It sets `services.nixi.companion.enable` and
    writes `~/.config/hypr/nixi-companion-binds.lua`.
  - p620 and razer import it.
  - Each host's user-owned `bindings.lua` gains one line:
    `pcall(require, "hypr.nixi-companion-binds")`. That is outside this repo,
    as gog's line is.

## Rollback

Revert the merge and deploy again, or boot the previous generation.
