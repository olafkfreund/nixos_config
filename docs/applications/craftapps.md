# Craft apps as default applications

The ArtCraft Craft apps are the default application for the file types they
declare. `modules/desktop/craftapps.nix` owns the mapping. It is enabled on
p620 and razer through `features.craftapps.enable`. p510 does not enable the
Craft apps and its defaults are unchanged.

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

- Video and audio keep the players they had (Totem, mpv, GNOME Music, Amberol
  and others, per type). FilmCraft and SoundCraft only take their own project
  files.
- Markdown, HTML and TeX stay on their current editor and browser, even though
  WordCraft can read them.
- Legacy `application/vnd.ms-excel` stays on LibreOffice Calc.

## Turning an app off

Change the app's existing line in the host's `features.craftapps.apps` block
(p620 and razer list every app explicitly, so adding a second line conflicts):

```nix
vectorcraft = false;
```

The app is not installed and its types are no longer forced to it. The default
then falls back to whatever the GNOME and Evince modules set, or the MIME cache.

For a shared type the module also writes the other Craft apps into
`[Removed Associations]`, so SVG does not move to FigCraft. Only GIO-based
openers honour that section (Nautilus, `gio open`, the GTK portal). Under
Hyprland, `xdg-open` and `xdg-mime` skip it and take the first entry in the MIME
cache: with CADCraft off, `xdg-open` on a DXF file opens VectorCraft.

## Where the mapping lives and how it is checked

`modules/desktop/craftapps.nix` holds the `defaults` table (app to MIME types)
and `alsoClaimed` (shared types). Defaults are written with `lib.mkForce` into
Home Manager's `xdg.mimeApps`, because the GNOME and Evince modules set their
own and those lists would otherwise merge.

Two guards run at build time:

- An assertion fails the build if one MIME type appears under two apps.
- The `craftapps-mime-check` derivation in `system.checks` reads each enabled
  app's desktop file and fails, naming the app and type, if it no longer
  declares a type in the table (or with a `sed` error if the desktop file is
  gone). A craftapps input bump that drops a type fails
  here instead of silently changing the default.

## Checking a host

```bash
for t in application/pdf image/png image/heic video/mp4 audio/flac; do
  printf '%-30s %s\n' "$t" "$(xdg-mime query default "$t")"
done
```

PDF, PNG and HEIC show a `ai.storyteller.*` desktop file. Video and audio show
Totem and GNOME Music.
