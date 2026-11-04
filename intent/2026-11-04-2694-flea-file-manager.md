---
status: draft
issue: 2694
author: olafkfreund
---

# Intent: Flea as the Omarchy file manager, through nixarchy-flea

## Problem

- **Flea now exists for NixOS but is not on any host.** github.com/olafkfreund/nixarchy-flea
  (merged 2026-11-04) packages Flea 0.4.0, upstream's prebuilt release in an FHS runtime.
  It provides a NixOS module (registration: portal backend, D-Bus services,
  gvfs/udisks2/usbmuxd) and a Home Manager module (default file manager, portal file
  picker, Hyprland binds). Nothing in this repo uses it yet.
- **The file-manager defaults point at Nautilus.** `home/desktop/gnome/default.nix:172` sets
  `xdg.mimeApps.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop"`.
  Omarchy's own Super+Shift+F binds Nautilus too. Flea's HM option writes the same key,
  so the two collide at evaluation.
- **The portal file chooser is GTK.** The user file `~/.config/xdg-desktop-portal/hyprland-portals.conf`
  is mutable today, holding `default=hyprland;gtk` and `Secret=gnome-keyring`. Flea's
  HM option would take it over, so those two lines must be carried, and the mutable file
  moved aside once.
- **Four runtime checks are still open from nixarchy-flea#1**, because they need the modules
  on a real host: FileManager1 ("Show in folder"), the portal picker,
  Super+Shift+F / Super+Alt+Shift+F, and the shelf plugin surviving a version bump.

## Proposed outcome

- `nixarchy-flea` is a flake input. A shared `hosts/common/nixos/omarchy-flea.nix`, in the
  same shape as `omarchy-ai-mirror.nix`, turns on the NixOS module and the HM module for
  `olafkfreund`, and each chosen host imports it from its `nixos/nixarchy.nix`.
- On those hosts, Flea is the default for folders, "Show in folder", the portal Open/Save
  dialog, and Super+Shift+F / Super+Alt+Shift+F. Nautilus stays installed, as a fallback.
- The existing portal routing keeps working: ScreenCast/Screenshot through hyprland,
  Secret through gnome-keyring.
- The four open runtime checks are run on the first host and recorded. That closes the
  verification nixarchy-flea#1 deferred.

## Affected users and systems

- Hosts: **p620** (local deploy) and **razer** (deploy via p620) run Omarchy and already
  import `omarchy-ai-mirror.nix` from their `nixos/nixarchy.nix`. **p510** is an Omarchy
  desktop too, but it is never built or deployed without asking (open question 1).
- User `olafkfreund`: HM-managed `mimeapps.list`, a new `~/.config/hypr/flea-binds.lua`, an
  HM-managed `hyprland-portals.conf`, and a FileManager1 D-Bus service file in
  `~/.local/share`.
- `home/desktop/gnome/default.nix`, whose Nautilus default is overridden on Flea hosts.
- System portal config: `xdg.portal` in `hosts/common/nixos/omarchy-sole-hyprland.nix`.
  Flea's NixOS module adds itself to `extraPortals`.

## Constraints

- Explicit imports only. No `mkIf cond true`. Services live in modules: Flea has no
  service of its own here; the NixOS module only registers files and turns on
  gvfs/udisks2/usbmuxd, which may already be on.
- The `ScreenCast→hyprland` routing named in `omarchy-sole-hyprland.nix` must not regress.
  Screen sharing is the known fragile path on these hosts.
- One-time manual steps cannot be done by a rebuild, because the files are user-owned (as
  for ai-mirror): add `pcall(require, "hypr.flea-binds")` to `bindings.lua`, and move
  the mutable `hyprland-portals.conf` aside before the first switch. Both are documented
  in the new file's header.
- Deploys follow the repo rules: build-test first, announce on the agent bus, p620
  locally, razer via p620, p510 only on request.
- Never use `flea --default` / `--picker` or Flea's Settings > About switch on these hosts:
  HM owns those files.

## Open questions

1. Which hosts: p620 only first (then razer after the checks pass), p620 + razer together,
   or all three including p510?
2. Optional dependencies: which to turn on? Video thumbnails need `ffmpegthumbnailer`;
   office previews need `libreoffice` (large); 7z, imagemagick, tailscale and zoxide are
   small. `dropbox` needs `allowUnfree`.
3. Follow `nixpkgs` in the input (`inputs.nixarchy-flea.inputs.nixpkgs.follows = "nixpkgs"`):
   yes, as for the other inputs here? (Flea is not compiled, so there is no cache to lose.)
4. Nautilus: keep it installed as a fallback (proposed), or remove it from Omarchy hosts?
