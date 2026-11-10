# Craft apps as default applications

The ArtCraft Craft apps are the default application for the file types they
declare. `modules/desktop/craftapps.nix` owns the mapping. It is enabled on
p620 and razer through `features.craftapps.enable`. p510 is unchanged and keeps
Evince and the GNOME defaults.

## Which app opens what

| App | Opens |
| --- | --- |
| WordCraft | Word (`.docx`, `.doc`, templates, macro-enabled), OpenDocument text, RTF |
| GridCraft | Excel (`.xlsx`, macro and binary variants), OpenDocument spreadsheet, CSV, TSV |
| DeckCraft | PowerPoint (`.pptx`, templates, slideshows), `.deckcraft` |
| PdfCraft | PDF |
| PhotoCraft | PNG, JPEG, TIFF, WebP, GIF, BMP, TGA, ICO, PNM, EXR, HDR, AVIF, QOI, PSD, Krita, OpenRaster, Paint.NET |
| LightCraft | HEIC/HEIF and camera raw (DNG, ARW, CR2, CR3, NEF, RAF, ORF, RW2, PEF) |
| VectorCraft | SVG, AI, EPS, EMF, WMF, Affinity |
| FigCraft | `.figcraft`, Sketch, `figcraft:` links |
| DesignCraft | `.designcraft`, InDesign IDML |
| CADCraft | DXF, DWG |
| FilmCraft | `.filmcraft` projects |
| SoundCraft | SoundCraft sessions |

EffectCraft and Craft Anything claim no types.

Several apps declare the same image types (PNG, JPEG, TIFF, WebP, GIF, BMP).
Each shared type has exactly one owner: PhotoCraft for the raster formats, PdfCraft
for PDF, VectorCraft for SVG, CADCraft for DXF.

## What stays where it was

- Video (`video/*`) stays on Totem or mpv, and audio (`audio/*`) on GNOME Music.
  FilmCraft and SoundCraft only take their own project files.
- Markdown, HTML and TeX stay on their current editor and browser, even though
  WordCraft can read them.
- Legacy `application/vnd.ms-excel` stays on LibreOffice Calc.

## Turning an app off

```nix
features.craftapps.apps.vectorcraft = false;
```

The app is not installed and its types are no longer forced to it. The default
then falls back to whatever the GNOME and Evince modules set. For a shared type
the module also removes the other Craft apps' claim, so SVG does not move to
FigCraft by accident.

## Where the mapping lives and how it is checked

`modules/desktop/craftapps.nix` holds the `defaults` table (app to MIME types)
and `alsoClaimed` (shared types). Defaults are written with `lib.mkForce` into
Home Manager's `xdg.mimeApps`, because the GNOME and Evince modules set their
own and those lists would otherwise merge.

Two guards run at build time:

- An assertion fails the build if one MIME type appears under two apps.
- The `craftapps-mime-check` derivation in `system.checks` reads each enabled
  app's desktop file and fails, naming the app and type, if it no longer
  declares a type in the table. A craftapps input bump that drops a type fails
  here instead of silently changing the default.

## Checking a host

```bash
for t in application/pdf image/png image/heic video/mp4 audio/flac; do
  printf '%-30s %s\n' "$t" "$(xdg-mime query default "$t")"
done
```

PDF, PNG and HEIC show a `ai.storyteller.*` desktop file. Video and audio show
Totem and GNOME Music.
