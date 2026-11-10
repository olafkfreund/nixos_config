---
status: draft
issue: 2838
author: olafkfreund
---

# Intent: make the Craft apps the default applications for their file types

## Problem

The ArtCraft Crafting Apps (`nix-craftapps`, `features.craftapps` in `modules/desktop/craftapps.nix`) are installed
on p620 and razer, and each one's desktop file lists the MIME types it handles. Nothing in this repo makes them the
default for those types. Observed on p620 (`xdg-mime query default`, 2026-11-10):

- `.docx`, `.xlsx` and `.pptx` open in WordCraft, GridCraft and DeckCraft, but LibreOffice (`writer`, `calc`,
  `impress`) claims the same types. Nothing declares the winner; it is whichever the MIME cache lists first.
- PDF opens in Evince, and raster images in eog: `home/desktop/gnome/apps.nix` (`:303-324`) and
  `home/desktop/evince/default.nix` (`:24-26`) set them in Home Manager's `xdg.mimeApps`. SVG also opens in eog,
  and Adobe `.ai` in Evince, through the MIME cache rather than this repo.
- Several Craft apps claim the same type: `image/png` is listed by FigCraft, LightCraft, PhotoCraft and VectorCraft;
  `application/pdf` by PdfCraft and VectorCraft; `image/svg+xml` by FigCraft and VectorCraft; `image/vnd.dxf` by
  CADCraft and VectorCraft. Each type needs one owner chosen on purpose.

## Proposed outcome

On every host with `features.craftapps.enable` (p620 and razer), double-clicking a file opens:

| Files | App |
| --- | --- |
| `.docx`, `.docm`, `.dotx`, `.doc`, ODT, RTF | WordCraft |
| `.xlsx`, `.xlsm`, `.xlsb`, ODS, CSV, TSV | GridCraft |
| `.pptx`, `.potx`, `.ppsx` | DeckCraft |
| PDF | PdfCraft |
| PNG, JPEG, WebP, GIF, TIFF, BMP, AVIF, QOI, TGA, ICO, PNM family, EXR, Radiance HDR | PhotoCraft |
| PSD, PSB, Krita, OpenRaster, Paint.NET | PhotoCraft |
| HEIC, HEIF and camera raw files (DNG, CR2, CR3, NEF, ARW and the rest) | LightCraft |
| SVG, compressed SVG, Illustrator, EPS, EMF, WMF, Affinity | VectorCraft |
| Sketch files and `figcraft:` links | FigCraft |
| IDML | DesignCraft |
| DWG and DXF | CADCraft |
| The apps' own project and template types (`application/x-deckcraft`, `-designcraft`, `-figcraft`, `-filmcraft`, `-photocraft`, `-vectorcraft`, `-vectorcraft-template`, `-soundcraft-session`) | that app |

- A Craft app becomes the default only for types its own desktop file declares. So legacy `.xls` and `.ppt`
  (declared by LibreOffice, not by GridCraft or DeckCraft) and `.odp` keep their current app.
- Video (Totem, mpv) and audio (GNOME Music) keep their players, by owner decision. FilmCraft's and SoundCraft's
  own project and session files do open in them. Every Craft app stays under "Open with" for all its types.
- Text types WordCraft also declares (`text/markdown`, `text/html`, `text/x-tex`) keep their editor and browser.
- The mapping is declared in this repo, so it survives installing another app that only adds a desktop file. An app
  that rewrites `~/.config/mimeapps.list` itself is out of scope; the next Home Manager activation restores it.
- An app turned off in `features.craftapps.apps` is not made a default. Its types go back to the non-Craft
  baseline (eog, Evince, LibreOffice and so on), not to another Craft app that also claims them.
- `xdg-mime query default <type>` shows the chosen app for each row.

## Affected users and systems

- `modules/desktop/craftapps.nix` (our wrapper around `inputs.nix-craftapps.nixosModules.default`).
- Home Manager `xdg.mimeApps` in `home/desktop/gnome/apps.nix` and `home/desktop/evince/default.nix`, which set
  the PDF and image defaults today.
- p620 and razer (`features.craftapps.enable`). p510 does not enable the Craft apps and keeps its defaults; it is
  not built or deployed here.
- The `olafkfreund` user on both hosts.

## Constraints

- The `nix-craftapps` flake input does not change; its MIME lists stay as published.
- Defaults only where `features.craftapps.enable` is true, and only for enabled apps.
- Home Manager writes `~/.config/mimeapps.list`, which wins over `/etc/xdg/mimeapps.list`, so the defaults must
  land in Home Manager. Home Manager merges `xdg.mimeApps.defaultApplications` lists across modules, so the existing
  Evince and eog lines must lose by option priority, not by being concatenated next to the Craft entry.
- Video, audio and the text types above stay as they are.
- Nothing is uninstalled: Evince, eog and LibreOffice stay and remain under "Open with".

## Open questions

- **Where the mapping lives.** Default: in `modules/desktop/craftapps.nix`, which sets the user's Home Manager
  `xdg.mimeApps.defaultApplications` above the priority of the GNOME and Evince entries, so one file owns it.
- **WordCraft for Markdown, HTML and TeX.** Default: no, they keep their editor and browser. Say so if Markdown
  should open in WordCraft.
- **Shared types.** The table picks one owner per type: JPEG and PNG to PhotoCraft, not LightCraft (a library and
  raw processor); SVG to VectorCraft, not FigCraft; PDF to PdfCraft, not VectorCraft; DXF to CADCraft, not
  VectorCraft.
