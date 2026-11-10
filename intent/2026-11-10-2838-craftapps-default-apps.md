---
status: draft
issue: 2838
author: olafkfreund
---

# Intent: make the Craft apps the default applications for their file types

## Problem

The ArtCraft Crafting Apps (`nix-craftapps`, `features.craftapps` in `modules/desktop/craftapps.nix`) are installed
on p620 and razer, and each one's desktop file lists the MIME types it handles. Nothing in this repo makes them the
default for those types:

- Office documents, spreadsheets, CSV, presentations, CAD drawings, raw photos, PSD and InDesign files open in a
  Craft app on p620 today only because no other installed app claims them. That is accidental: installing another
  app that claims `.docx` or `.xlsx` could silently take the default.
- PDF opens in Evince (`home/desktop/evince/default.nix`, `home/desktop/gnome/apps.nix`), raster images in eog
  (`gnome/apps.nix`), SVG in eog, and Adobe `.ai` files in Evince.
- Several Craft apps claim the same type (`image/png` is listed by FigCraft, LightCraft, PhotoCraft and VectorCraft;
  `application/pdf` by PdfCraft and VectorCraft), so even without other apps the winner is not chosen on purpose.

## Proposed outcome

On every host with `features.craftapps.enable` (p620 and razer), double-clicking a file opens:

| Files | App |
| --- | --- |
| Word, OpenDocument text, RTF | WordCraft |
| Excel, OpenDocument spreadsheet, CSV | GridCraft |
| PowerPoint | DeckCraft |
| PDF | PdfCraft |
| PNG, JPEG, WebP, GIF, TIFF, BMP | PhotoCraft |
| PSD and other layered image formats | PhotoCraft |
| Camera raw files (DNG, CR2, CR3, NEF, ARW and the rest) | LightCraft |
| SVG, Adobe Illustrator, EPS | VectorCraft |
| InDesign (IDML) | DesignCraft |
| DWG and DXF | CADCraft |
| Each app's own project format (`application/x-<app>`) | that app |

- A Craft app becomes the default only for types its own desktop file declares (for example, DeckCraft lists no
  OpenDocument presentation type, so `.odp` is left alone).
- Video (Totem, mpv) and audio (GNOME Music) keep their players, by owner decision. FilmCraft, SoundCraft and the
  others stay available under "Open with" for every type their desktop file lists.
- The mapping is declared in this repo, so it survives installing another app, and `xdg-mime query default <type>`
  shows the Craft app for each row.
- An app turned off in `features.craftapps.apps` is not made a default, and its types fall back to what they are
  today.

## Affected users and systems

- `modules/desktop/craftapps.nix` (our wrapper around `inputs.nix-craftapps.nixosModules.default`).
- Home Manager `xdg.mimeApps` in `home/desktop/gnome/apps.nix` and `home/desktop/evince/default.nix`, which set
  PDF and image defaults today and would conflict.
- p620 and razer (`features.craftapps.enable`). p510 does not enable the Craft apps and keeps its defaults; it is
  not built or deployed here.
- The `olafkfreund` user on both hosts.

## Constraints

- No change to the `nix-craftapps` flake input itself; its MIME lists stay as published.
- Defaults are set only where `features.craftapps.enable` is true, and only for apps that are enabled.
- Home Manager writes `~/.config/mimeapps.list`, which wins over the system list, so the defaults must land there
  (or override it), not only in `/etc/xdg`.
- Video and audio defaults stay as they are.
- No app is removed: Evince and eog stay installed and remain under "Open with".

## Open questions

- **Where the mapping lives.** Default: in `modules/desktop/craftapps.nix`, which sets Home Manager's
  `xdg.mimeApps.defaultApplications` for the user, so one file owns it and the Evince and eog lines lose only where
  craftapps is on.
- **Types several Craft apps claim.** The table above picks one owner per type. Default: a JPEG or PNG goes to
  PhotoCraft even though LightCraft also claims it, because LightCraft is a library and raw processor.
