---
status: approved
issue: 1967
spec: spec/2026-09-22-1967-hyprflip-hy3-containers.md
---

# Plan: load the hy3 container provider for Hyprflip on p620

## Approved decisions (from the spec)

- **One module, `hosts/common/nixos/omarchy-hyprflip.nix`**, imported only by
  `hosts/p620/nixos/nixarchy.nix`. It writes `~/.config/hypr/hyprflip.lua` via
  `home-manager.users.olafkfreund.home.file`, guarded with
  `lib.attrByPath [ "programs" "hyprflip" ] { enable = false; } config`, because
  razer and p510 do not have the option.
- **One generated file:**
  - the current hand-written `hyprflip.lua`, **verbatim** (41 lines, sha256
    `8fd141c39e23af84f5eeb41354a9a305fc3aa7e2c496f6285d5a96e2c227c7bf` as of
    2026-09-22 23:1x), under a "managed by" header;
  - then, only when `containers.enable`, the hy3 block adapted from upstream
    `examples/containers-trial.lua`: `hl.plugin.load("/etc/hyprflip/libhy3.so")`,
    `hl.workspace_rule({ workspace = "8", layout = "hy3" })` inside
    `if hl.plugin.hy3`, and Super+Ctrl+Alt+H/V/E (+O if `unfold`) guarded on
    `hl.plugin.hyprflip.attach` and resolved at press time.
- **`~/.config/hypr/autostart.lua`:** a hand edit, bare
  `require("hypr.hyprflip")` → `pcall(require, "hypr.hyprflip")`, made before the
  switch.
- **Home Manager takes over the regular file** through the existing
  `backupCommand`, which moves the old file to `~/.hm-backups/`.
- **It takes effect at re-login, never with `hyprctl reload`.** The switch only
  writes files.
- **The crash risk is tested first:** a nested-session proof with the built
  libraries before any real login.
- **Out of scope:** the OmaCards helper files (own issue) and hy3 on other
  workspaces.
- **Only p620 changes.** razer and p510 must still evaluate.

## Preconditions (checked before step 6, not before coding)

- **P1.** PR #1969 (#1968) is merged, and this branch is rebased onto `main`. If
  it is not merged yet, the switch is built from this branch, which contains it.
- **P2. The owner's staged `hosts/p620/nixarchy/apps.nix`.** p620's running
  generation (`cfyl904…`) includes it, because it was built from the dirty
  checkout. A switch built from committed refs drops that edit until it is
  committed. **The owner decides:** commit it first, or accept the rollback.
  Nothing proceeds to step 6 without that answer.
- **P3.** Nothing p620 runs is missing from the build: compare with the running
  system's `/etc/hyprflip` and the Home Manager unit, as in #1968's check. PR
  #1966 (dd8139's nix-skills change) is included if it is merged by then;
  otherwise its four duplicate links come back, which dd8139 called harmless.

## Steps

1. **Stop if the hand file has changed.** Run
   `sha256sum ~/.config/hypr/hyprflip.lua` and require `8fd141c3…`. If it differs,
   stop and ask, because someone edited the loader since the spec.

2. **`hosts/common/nixos/omarchy-hyprflip.nix`:** create the module.
   - Header comment in the style of `omarchy-meet-binds.nix`: what it does, the
     `attrByPath` reason, and the `pcall` requirement for the user-owned
     `autostart.lua`.
   - `text` = header lines
     (`-- Managed by hosts/common/nixos/omarchy-hyprflip.nix -- edits here are overwritten on the next deploy.`),
     then the 41-line hand file byte for byte, then
     `lib.optionalString cfg.containers.enable` with the hy3 block.
   - Verify by `nix-instantiate --parse` on the file.

3. **`hosts/p620/nixos/nixarchy.nix`:** add
   `../../common/nixos/omarchy-hyprflip.nix` to `imports`, directly after
   `inputs.hyprflip.nixosModules.default`. Verify by `just check-syntax`.

4. **Build and inspect.**
   - `nix build .#nixosConfigurations.p620.config.system.build.toplevel`
     succeeds.
   - razer and p510 evaluate: `nix eval .#nixosConfigurations.{razer,p510}.config.system.build.toplevel.drvPath`.
   - The generated file (from the built `home-manager-files`), with its header
     and hy3 block stripped, is byte-identical to the hand file: sha256
     `8fd141c3…`.
   - The hy3 block sits after `hl.plugin.load("/etc/hyprflip/hyprflip.so")`.

5. **Nested-session proof.** The built system's `/etc/hyprflip` must equal the
   running one's; if it differs, use the built paths.
   - Copy the pinned fork source to a short writable path (`/tmp/hfn`).
   - Create `build/containers/core/hyprflip.so` and
     `build/containers/provider/upstream/libhy3.so` there as symlinks to the
     built `/etc/hyprflip/{hyprflip.so,libhy3.so}`.
   - Confirm `Hyprland --version` is `23118f9f`.
   - Start `python3 tests/nested_session.py --directory /tmp/hfs --containers`
     in the background. Against its runtime dir
     (`XDG_RUNTIME_DIR=/tmp/hfs/runtime`), `hyprctl -j plugin list` must list
     `hyprflip` and `hy3`, and `hyprctl hyprflip status` must show
     `container_provider: true` and `container_max_panes: 3`.
   - Stop it with SIGINT, confirm no nested Hyprland is left
     (`ps -eo args | grep '[H]yprland'` shows only the session's), then remove
     `/tmp/hfn` and `/tmp/hfs`.
   - Any crash or a missing provider **stops the plan**. Nothing gets committed
     for deploy.

6. **Commit** `feat(hyprflip): load the hy3 container provider on p620 (#1967)`,
   then push. Settle P1–P3.

7. **Switch p620.**
   - Read the bus, and post about the switch, the ~5 min it takes, and that
     nothing loads until re-login.
   - Edit `autostart.lua` to use `pcall`, back up the original to
     `~/.config/hypr/autostart.lua.bak-1967`, and confirm with `diff`.
   - Build from the committed ref (`git+file://…?ref=…`), then switch.
   - Afterwards: `~/.config/hypr/hyprflip.lua` is a Home Manager symlink, the old
     file is in `~/.hm-backups/`, and there are no failed units.
   - The running session is untouched, with no reload: `hyprctl -j plugin list`
     is unchanged.

8. **Owner re-logs in**, then run the live checks:
   - `hyprctl -j plugin list` shows `hyprflip` and `hy3`;
   - `hyprctl hyprflip status` shows provider `true` and max panes `3`;
   - `hyprctl configerrors` is empty;
   - OmaCards helper `snapshot` reports `containers: true`;
   - M/S/F/U flip and Super+Space (shell) still work;
   - the running shell's tree equals the session's `OMARCHY_PATH`.

   Post the results on the bus.

9. **Open the PR** linking the intent, spec and plan, #1967 and #1969, with the
   step 5 and step 8 evidence. Open the separate issue for the OmaCards helper
   files.

## Tests

| Check | Expected |
| --- | --- |
| `nix build …p620…toplevel` | Succeeds |
| razer and p510 `drvPath` eval | Both evaluate |
| Generated `hyprflip.lua` minus header/hy3 block | sha256 `8fd141c3…` |
| Nested session with the built libraries | `hyprflip` and `hy3` loaded; provider `true`, max panes `3`; no crash |
| Live after re-login | Same as nested, plus `configerrors` empty, helper `containers: true`, and existing binds working |

## Rollback

- **Before re-login:** `sudo nixos-rebuild switch --rollback` (after a bus
  notice). It restores the previous Home Manager generation. If the hand file is
  still wanted, restore it from `~/.hm-backups/`.
- **If a login fails:** choose GNOME at the greeter (or use a TTY) and roll back
  as above. Alternatively set `programs.hyprflip.containers.enable = false` and
  rebuild, which keeps the core plugin.
- **`autostart.lua`:** the `pcall` edit is safe to keep. The original is at
  `autostart.lua.bak-1967`.
- **After merge:** `git revert` the feature commit. The module and import are
  self-contained.
