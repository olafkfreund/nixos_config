---
status: approved
issue: 2694
intent: intent/2026-11-04-2694-flea-file-manager.md
---

# Spec: Flea as the Omarchy file manager, through nixarchy-flea

## Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Hosts | **p620 and razer**, deployed from the branch for testing (owner, 2026-11-04). p510 is out of scope. |
| 2 | Optional dependencies | `ffmpegthumbnailer`, `sevenzip`, `imagemagick`, `zoxide`. Not `libreoffice` (large) or `dropbox` (unfree). `htmlPreview` stays on (the default). |
| 3 | `nixpkgs.follows` | Yes. Flea is not compiled, so there is no cache to lose. |
| 4 | Nautilus | Stays installed, as a fallback and for "Open with". |
| 5 | GNOME session (Codex) | Flea is the folder default in GNOME too. HM `mimeApps` is per user, not per session, and a per-session split would need a session-detecting wrapper that nobody asked for. Nautilus is still one "Open with" away. |

## Design

### Files

```text
flake.nix                                  + input nixarchy-flea (nixpkgs + home-manager follow)
hosts/common/nixos/omarchy-flea.nix        new: NixOS + HM wiring, header with the one-time steps
hosts/p620/nixos/nixarchy.nix              + import ../../common/nixos/omarchy-flea.nix
hosts/razer/nixos/nixarchy.nix             + import ../../common/nixos/omarchy-flea.nix
```

### `flake.nix`

Next to the other `nixarchy-*` inputs:

```nix
# nixarchy-flea: Flea file manager (prebuilt upstream binaries in an FHS runtime);
# hosts/common/nixos/omarchy-flea.nix.
nixarchy-flea = {
  url = "github:olafkfreund/nixarchy-flea";
  inputs.nixpkgs.follows = "nixpkgs";
  # Used only by nixarchy-flea's own checks; follow ours so the lock has one copy.
  inputs.home-manager.follows = "home-manager";
};
```

### `hosts/common/nixos/omarchy-flea.nix`

This follows the shape of `omarchy-ai-mirror.nix`, the precedent for an external Omarchy
app with an HM bind file:

```nix
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
    # home/desktop/gnome/default.nix sets Nautilus at normal priority, and mimeApps lists
    # merge, so the result would be both, in an unspecified order.
    xdg.mimeApps.defaultApplications."inode/directory" = lib.mkForce [ "com.thisisgm.flea.desktop" ];
  };
}
```

The header comment states:

- what Flea is, and that the package registers the portal backend and FileManager1;
- the one-time step per machine: append `pcall(require, "hypr.flea-binds")` at the **end**
  of `~/.config/hypr/bindings.lua`. It must come after Omarchy's defaults, which
  `hyprland.lua` loads first, so that Flea's `hl.unbind` replaces Nautilus's keys. It is
  safe to add before the deploy, because `pcall` ignores a missing file.
- no manual move of the mutable `hyprland-portals.conf`. This repo's `home-manager.backupCommand`
  (`flake.nix`) moves a conflicting file to `~/.hm-backups/<timestamp>/` on the switch. A
  manual `mv` after the switch would move the new HM symlink instead (agy).
- never to use `flea --default`, `--picker` or Settings > About on these hosts.

**Repo rule 1 ("services belong in `modules/`")**: the NixOS module defines no service of
its own. It registers files and sets `mkDefault true` on nixpkgs' `services.gvfs`,
`services.udisks2` and `services.usbmuxd`. gvfs and udisks2 are already on for p620
(checked). The only new one is usbmuxd, for iPhones, and it uses nixpkgs' stock module.
Rule 2 (service hardening) is for this repo's own services, so it does not apply.
`hosts/common/nixos/` is where every other external Omarchy app (ai-mirror, gog, meet-binds)
is wired, so the file goes there, following precedent.

### Host imports

Each host gets one line, next to `../../common/nixos/omarchy-ai-mirror.nix`, in
`hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`.

## Rollout (test deploy, then PR)

1. `just validate`, `just test-host p620` and `just test-host razer` from the worktree.
2. The owner adds the `pcall` line on p620 (safe before the deploy).
3. Agent bus for p620: `read_new("#agents:freundcloud.org.uk")`, then `post` "deploying p620
   from feat/2694 (Flea), ~5 min". If someone is mid-flight, wait.
4. p620: `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just p620` from the worktree. HM backs up
   the mutable `hyprland-portals.conf` to `~/.hm-backups/`.
5. The owner logs out and in, so the portal and Hyprland pick up the new files.
6. Runtime checks 7–10 and P on p620 (Verification).
7. razer: the `pcall` line there, a fresh bus read and post, then
   `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`, a re-login, and spot
   checks.
8. Open the PR to `main`. After merge, the normal `main` deploys bring both hosts back onto
   `main` with the same config.

Rollback: `just p620` / `just deploy-via-p620 razer` from `main`. That removes Flea and the
HM portal file, and the system `hyprland-portals.conf` (from `pkgs.hyprland`) then applies.
That file keeps ScreenCast on hyprland but lacks the `Secret=gnome-keyring` line, so also
restore the old user file from `~/.hm-backups/<timestamp>/.config/xdg-desktop-portal/` (agy).

## Alternatives rejected

- **A `features.flea.enable` module under `modules/`.** It would be one wrapper option
  around two upstream modules that already have `enable`. The repo's precedent for
  external Omarchy apps is `hosts/common/nixos/omarchy-*.nix`.
- **Changing `home/desktop/gnome/default.nix`.** That would edit a GNOME module for an
  Omarchy concern. One `mkForce` in the Flea file keeps the change in one place, and
  reverting the Flea file restores Nautilus.
- **Session-specific defaults (Flea in Omarchy, Nautilus in GNOME).** See decision 5.
- **p510 now.** The repo rule: never without asking. It is not asked for.

## Risks

| Risk | Mitigation |
|---|---|
| Screen sharing regresses: the user `hyprland-portals.conf` now overrides the system one | The file keeps `default=hyprland;gtk` and has no ScreenCast key, so ScreenCast falls through to `hyprland`. Verified by a screen-share test (check P). |
| HM meets the mutable `hyprland-portals.conf` | `backupCommand` moves it to `~/.hm-backups/` (checked in `flake.nix`). `mimeapps.list` is HM-managed already (checked). If activation fails, `home-manager-olafkfreund.service` says which file. |
| Nautilus still wins "Show in folder" | The HM file in `~/.local/share/dbus-1/services` is read before system files. Check 7 verifies it. |
| Super+Shift+F still opens Nautilus | The `pcall` line goes at the end of `bindings.lua`. Check 9. |
| A branch deploy is left running if the PR stalls | The PR is opened right after the checks. `just p620` from `main` reverts. |
| razer's build on p620 takes long | Flea is not compiled, but `htmlPreview` (qt6-webengine) and the optional packages make a large closure. They come from `cache.nixos.org`, so it is mostly download time. |

## Verification

Build:

1. `just test-host p620` and `just test-host razer` succeed.
2. `nix eval` on p620's config:
   - `programs.flea.enable` is true
   - HM `xdg.mimeApps.defaultApplications."inode/directory"` is exactly
     `["com.thisisgm.flea.desktop"]`
   - HM `xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text` contains
     `default=hyprland;gtk`, the `Secret` line and `FileChooser=flea;gtk`

Runtime, on p620 after the deploy (results go on #2694 and nixarchy-flea#1):

- **7**: `gio open ~` opens Flea; Firefox "Show in folder" on a download opens Flea; and
  `busctl --user status org.freedesktop.FileManager1` names the flea-fhs process.
- **8**: a portal Open dialog (Firefox upload, or `zenity --file-selection` through the
  portal) shows Flea's picker, floating.
- **9**: Super+Shift+F and Super+Alt+Shift+F open Flea.
- **10**: the shelf plugin, enabled in Flea, survives a simulated version bump (edit the
  copied manifest version, relaunch, toggle).
- **P**: screen sharing in a browser (or `xdg-desktop-portal` debug output) still picks
  the hyprland ScreenCast backend, and a keyring prompt still uses gnome-keyring.

razer: 1, 7, 9 and P as spot checks.
