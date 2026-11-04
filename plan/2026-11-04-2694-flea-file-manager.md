---
status: approved
issue: 2694
spec: spec/2026-11-04-2694-flea-file-manager.md
coders:
  1: coder   # the input block, the new omarchy-flea.nix and two import lines: exact text given, mechanical
reviewers:
  - codex    # independent read of the Nix diff against this plan
  - agy      # independent read of the rollout against AGENTS.md
---

# Plan: Flea as the Omarchy file manager, through nixarchy-flea

## Approved decisions (from spec, self-contained)

- New flake input `nixarchy-flea` (`github:olafkfreund/nixarchy-flea`), following our
  `nixpkgs` and `home-manager`.
- A new `hosts/common/nixos/omarchy-flea.nix`, in the ai-mirror shape, imported by p620 and
  razer only (p510 is out of scope).
  - NixOS module: optional deps `ffmpegthumbnailer`, `sevenzip`, `imagemagick` and
    `zoxide`, with `htmlPreview` at its default (on).
  - HM module for `olafkfreund`: `defaultFileManager`, `filePicker` (with `extraConfig`
    carrying `default=hyprland;gtk` and `org.freedesktop.impl.portal.Secret=gnome-keyring`)
    and `hyprland.bindings`.
  - `mkForce` on `inode/directory`, because the GNOME module's Nautilus value would
    otherwise merge into the list.
- Nautilus stays installed. Flea is the folder default in GNOME too (mimeApps is per user).
- No manual move of `hyprland-portals.conf`: this repo's `home-manager.backupCommand` backs it
  up to `~/.hm-backups/<timestamp>/` on the switch.
- The one manual step per host: append `pcall(require, "hypr.flea-binds")` to the end of
  `~/.config/hypr/bindings.lua`. It is safe before the deploy.
- Test deploy from the branch: `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1`, after
  `just validate` and `just test-host`, with a bus read and post before each host. p620
  goes first, then razer via p620. The PR to `main` comes after the checks.

Repo traps (AGENTS.md):

- Work only in `~/.config/nixos-2694`. Never check out a branch in `~/.config/nixos`.
- Explicit imports only; no `mkIf cond true`.
- Conventional Commits with `(#2694)`. A markdownlint pre-push hook requires a language on
  every fenced block.
- Untracked files are invisible to the flake: `git add` before building.

## Steps

1. **Edit three places and create one file** (coder):
   - `flake.nix`: after the `nixarchy-meetingai = { … };` block (ends at line 174), insert:

     ```nix

         # nixarchy-flea: Flea file manager (prebuilt upstream binaries in an FHS
         # runtime); hosts/common/nixos/omarchy-flea.nix.
         nixarchy-flea = {
           url = "github:olafkfreund/nixarchy-flea";
           inputs.nixpkgs.follows = "nixpkgs";
           # Used only by nixarchy-flea's own checks; follow ours so the lock has one copy.
           inputs.home-manager.follows = "home-manager";
         };
     ```

   - New `hosts/common/nixos/omarchy-flea.nix`, exactly:

     ```nix
     # Flea: the Omarchy file manager (thisisgm/flea), from the nixarchy-flea flake
     # (upstream's prebuilt binaries in an FHS runtime). The NixOS module registers Flea's
     # portal file chooser backend and its FileManager1 D-Bus service, and turns on
     # gvfs/udisks2/usbmuxd (mkDefault). The Home Manager part makes Flea the folder
     # default, the portal file picker and the Super+Shift+F / Super+Alt+Shift+F app.
     #
     # One step per machine that a rebuild cannot do, because the file is user-owned
     # (same caveat as omarchy-ai-mirror.nix):
     #   append at the END of ~/.config/hypr/bindings.lua:  pcall(require, "hypr.flea-binds")
     #   It must come after Omarchy's default binds (hyprland.lua loads those first) so
     #   Flea's hl.unbind replaces Nautilus's keys. pcall makes it safe before the deploy.
     #
     # The first switch backs up the old mutable ~/.config/xdg-desktop-portal/hyprland-portals.conf
     # to ~/.hm-backups/<timestamp>/ (home-manager.backupCommand in flake.nix). After a
     # rollback, restore it from there: it carries the Secret=gnome-keyring line.
     #
     # Never use `flea --default`, `flea --picker` or Flea's Settings > About switch here:
     # Home Manager owns the files they would edit.
     { inputs, lib, ... }:
     {
       imports = [ inputs.nixarchy-flea.nixosModules.flea ];

       programs.flea = {
         enable = true;
         optionalDependencies = {
           ffmpegthumbnailer = true;
           sevenzip = true;
           imagemagick = true;
           zoxide = true;
         };
       };

       home-manager.users.olafkfreund = {
         imports = [ inputs.nixarchy-flea.homeManagerModules.flea ];
         programs.flea = {
           enable = true;
           defaultFileManager.enable = true;
           filePicker = {
             enable = true;
             # The lines the mutable hyprland-portals.conf held before Flea took the file over.
             extraConfig = {
               default = "hyprland;gtk";
               "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
             };
           };
           hyprland.bindings.enable = true;
         };
         # home/desktop/gnome/default.nix sets Nautilus at normal priority, and mimeApps
         # lists merge, so the result would be both, in an unspecified order.
         xdg.mimeApps.defaultApplications."inode/directory" = lib.mkForce [ "com.thisisgm.flea.desktop" ];
       };
     }
     ```

     Then `git add hosts/common/nixos/omarchy-flea.nix` (the flake ignores untracked files).
   - `hosts/p620/nixos/nixarchy.nix:36` and `hosts/razer/nixos/nixarchy.nix:36`: below
     `../../common/nixos/omarchy-ai-mirror.nix`, add
     `../../common/nixos/omarchy-flea.nix`.
   - `nix flake lock --update-input nixarchy-flea` (or `nix flake lock`). Only the new
     input's nodes may change in `flake.lock`.
   → verify (me):
     - `git diff HEAD --stat` shows exactly these 5 files (`git diff --stat` misses a new file)
     - `nix flake metadata --json | jq '.locks.nodes | keys'` has no second
       `home-manager` node from nixarchy-flea
     - `nixpkgs-fmt --check hosts/common/nixos/omarchy-flea.nix flake.nix hosts/*/nixos/nixarchy.nix`
       is clean (the repo formatter, as in `just format-path`)
   Traps: keep the inputs block's 4-space indentation. The new file takes `{ inputs, lib, ... }`.

2. **Evaluate and build** (me):
   - `nix eval --json .#nixosConfigurations.p620.config.programs.flea.enable` → `true`
   - `…home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications."inode/directory"`
     → `["com.thisisgm.flea.desktop"]`
   - `…home-manager.users.olafkfreund.xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text`
     contains `default=hyprland;gtk`, `org.freedesktop.impl.portal.Secret=gnome-keyring` and
     `FileChooser=flea;gtk`
   - `nix eval --json .#nixosConfigurations.p620.config.xdg.portal.extraPortals --apply 'map (p: p.name)'`
     contains `"flea-0.4.0"` (derivations can't be printed as JSON, hence `--apply`)
   - `just validate`, `just test-host p620`, `just test-host razer`
   → verify: all succeed. Commit steps 1–2 as `feat(desktop): Flea file manager on p620 and razer (#2694)`, then push.

3. **Deploy p620** (me, with you):
   - you add the `pcall` line at the end of p620's `~/.config/hypr/bindings.lua`
   - I `read_new("#agents:freundcloud.org.uk")`, then `post` "deploying p620 from
     feat/2694-flea-file-manager (Flea file manager), ~5 min". If someone is mid-flight, I wait.
   - `cd ~/.config/nixos-2694 && AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620`
   - you log out and back in
   → verify: the switch succeeds; `ls -la ~/.config/xdg-desktop-portal/hyprland-portals.conf`
     is an HM symlink; `ls ~/.hm-backups/*/.config/xdg-desktop-portal/` holds the old file;
     `~/.config/hypr/flea-binds.lua` exists.

4. **Runtime checks on p620** (you, me reading the system side):
   - 7: `gio open ~` and Firefox "Show in folder" open Flea; `busctl --user status org.freedesktop.FileManager1` names flea-fhs
   - 8: a portal Open dialog shows Flea's picker, floating
   - 9: Super+Shift+F and Super+Alt+Shift+F open Flea
   - 10: the shelf survives a simulated version bump
   - P: browser screen share still uses the hyprland backend; a keyring prompt still works
   → verify: results recorded on #2694 and on nixarchy-flea#1. Any failure stops the
     rollout; the fix goes through this plan as a deviation.

5. **Deploy razer** (me, with you): the `pcall` line there; a fresh bus read and post;
   `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`, run on p620. Its
   build step then builds locally on p620, and the switch reuses that output. Then a
   re-login on razer.
   → verify: checks 1, 7, 9 and P pass on razer.

6. **PR** (me): open `feat/2694-flea-file-manager` → `main`, linking intent, spec and plan
   and saying which step the coder did. Reviews: a fresh Opus agent on the plan and the diff,
   plus Codex and agy (read-only). After you merge, the normal `main` deploys (`just p620`,
   `just deploy-via-p620 razer`) bring both hosts back onto `main`.

## Tests

| Command | Expected |
|---|---|
| `nix eval` (step 2) | the four values above |
| `just validate` | passes |
| `just test-host p620` / `just test-host razer` | both build |
| runtime 7, 8, 9, 10, P (p620); 7, 9, P (razer) | pass, recorded on #2694 |

## Rollback

Per host. A rollback is a deploy, so the bus read and post and `AGENT_BUS_ANNOUNCED=1`
apply too. From `~/.config/nixos` on `main`:

```bash
AGENT_BUS_ANNOUNCED=1 just p620                    # or: AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer
```

Then, **on that host** (`ssh razer` for razer), restore the newest backup of the old user
portal file and reload the portal:

```bash
b=$(ls -d ~/.hm-backups/*/.config/xdg-desktop-portal/hyprland-portals.conf | sort | tail -1)
mkdir -p ~/.config/xdg-desktop-portal && cp "$b" ~/.config/xdg-desktop-portal/
systemctl --user restart xdg-desktop-portal
```

Remove the `pcall` line from `bindings.lua`, or leave it: `pcall` is harmless once the
file is gone.
