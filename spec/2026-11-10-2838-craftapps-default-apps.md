---
status: approved
issue: 2838
intent: intent/2026-11-10-2838-craftapps-default-apps.md
---

# Spec: make the Craft apps the default applications for their file types

## Design

All logic goes in `modules/desktop/craftapps.nix`, our wrapper around `inputs.nix-craftapps.nixosModules.default`.
The PDF-only override that #2837 added to `hosts/p620/configuration.nix:500-506` and
`hosts/razer/configuration.nix:322-327` moves into it: those two `home-manager.sharedModules` blocks are deleted,
or two forced `application/pdf` definitions would concatenate.

### The mapping: one attrset, app → exact MIME types

A `defaults` attrset in `craftapps.nix` holds these strings, each copied from that app's `MimeType=` line
(nix-craftapps rev `848f049f`):

| App | Types |
| --- | --- |
| `wordcraft` | `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `application/vnd.ms-word.document.macroEnabled.12`, `application/vnd.openxmlformats-officedocument.wordprocessingml.template`, `application/vnd.ms-word.template.macroEnabled.12`, `application/msword`, `application/msword-template`, `application/vnd.oasis.opendocument.text`, `application/rtf`, `text/rtf` |
| `gridcraft` | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `application/vnd.ms-excel.sheet.macroEnabled.12`, `application/vnd.ms-excel.sheet.binary.macroEnabled.12`, `application/vnd.oasis.opendocument.spreadsheet`, `text/csv`, `text/tab-separated-values` |
| `deckcraft` | `application/x-deckcraft`, `application/vnd.openxmlformats-officedocument.presentationml.presentation`, `application/vnd.openxmlformats-officedocument.presentationml.template`, `application/vnd.openxmlformats-officedocument.presentationml.slideshow` |
| `pdfcraft` | `application/pdf` |
| `photocraft` | `application/x-photocraft`, `image/x-paintnet`, `image/openraster`, `application/x-krita`, `image/vnd.adobe.photoshop`, `image/x-psd`, `image/x-psb`, `image/png`, `image/jpeg`, `image/tiff`, `image/webp`, `image/gif`, `image/bmp`, `image/x-tga`, `image/x-icon`, `image/vnd.microsoft.icon`, `image/x-portable-anymap`, `image/x-portable-bitmap`, `image/x-portable-graymap`, `image/x-portable-pixmap`, `image/x-exr`, `image/vnd.radiance`, `image/avif`, `image/qoi` |
| `lightcraft` | `image/heic`, `image/heif`, `image/x-adobe-dng`, `image/x-sony-arw`, `image/x-canon-cr2`, `image/x-canon-cr3`, `image/x-nikon-nef`, `image/x-fuji-raf`, `image/x-olympus-orf`, `image/x-panasonic-rw2`, `image/x-panasonic-rw`, `image/x-pentax-pef` |
| `vectorcraft` | `image/svg+xml`, `application/x-vectorcraft`, `image/svg+xml-compressed`, `application/illustrator`, `application/x-ai-template`, `application/x-vectorcraft-template`, `image/emf`, `image/wmf`, `image/x-eps`, `application/x-affinity` |
| `figcraft` | `application/x-figcraft`, `application/x-sketch`, `x-scheme-handler/figcraft` |
| `designcraft` | `application/x-designcraft`, `application/vnd.adobe.indesign-idml-package` |
| `cadcraft` | `image/vnd.dxf`, `image/vnd.dwg`, `application/x-dxf`, `application/acad` |
| `filmcraft` | `application/x-filmcraft` |
| `soundcraft` | `application/x-soundcraft-session` |

Left out on purpose: WordCraft's `text/markdown`, `text/x-tex`, `text/html`; FilmCraft's video and SoundCraft's
audio types; the types a second Craft app also declares (LightCraft's and FigCraft's PNG, JPEG, TIFF, WebP, SVG;
VectorCraft's PDF, DXF and raster types). `effectcraft` and `craft-anything` declare no types.

### Where it lands: a Home Manager shared module, by priority

`craftapps.nix` adds, under `lib.mkIf cfg.enable`, one `home-manager.sharedModules` entry:

- `xdg.mimeApps.enable = true`.
- `xdg.mimeApps.defaultApplications.<type> = lib.mkForce [ "<desktopId>.desktop" ]` for every type of every
  **enabled** app. `desktopId` comes from the flake input's `apps.json`, which `craftapps.nix` already reads.
- `lib.mkForce` per type, as #2837 did for PDF: Home Manager concatenates equal-priority `defaultApplications`
  lists, so a plain definition would sit next to eog (`home/desktop/gnome/apps.nix`) and Evince
  (`home/desktop/evince/default.nix`). At force priority only the Craft entry is kept, for those types only.
- `sharedModules` reaches every Home Manager user on the host (today `olafkfreund` on p620 and razer).

### A disabled owner falls back to the non-Craft app

For each **disabled** app, its types get `xdg.mimeApps.associations.removed.<type>` listing every enabled Craft app
that also declares that type (from the same `apps.json` and the left-out list above). The MIME cache then cannot
pick, say, FigCraft for SVG when VectorCraft is off, and the type falls back to the GNOME, Evince or LibreOffice
default. The cost: in that case those Craft apps leave "Open with" for that type.

### Two guards

- **One owner per type**, a NixOS `assertions` entry over `defaults`: no type appears under two apps. Because
  equal-priority `mkForce` lists would concatenate, this is what keeps one entry per type.
- **Declared types only**, one `system.checks` derivation (built with the system, no import-from-derivation). For
  each enabled app it turns the package's `share/applications/<desktopId>.desktop` `MimeType=` value into
  `;a;b;…;` and checks `;<type>;` for every mapped type, so `image/svg+xml` cannot pass on
  `image/svg+xml-compressed`. It fails naming any type the app no longer declares, so a nix-craftapps update that
  drops one breaks `just test-host`.

The GNOME and Evince modules are not edited: on p510, and any host without craftapps, they apply as today.

## Alternatives rejected

- **Generate the mapping from the desktop files.** That is import-from-derivation at eval time, and the shared
  types would still need a hand-written owner.
- **Each app's whole `MimeType=` list minus exclusions, computed.** Same import-from-derivation problem; the
  literal table is reviewable and the check keeps it honest.
- **System-wide `xdg.mime.defaultApplications`** (`/etc/xdg/mimeapps.list`). Home Manager's
  `~/.config/mimeapps.list` wins over it.
- **Edit `gnome/apps.nix` and `evince/default.nix`** to use `mkDefault`. Spreads the rule over three files and
  changes hosts without the Craft apps.
- **Keep #2837's host blocks and add the rest beside them.** Two places own PDF, and the forced lists concatenate.
- **A per-user module in `Users/olafkfreund/`.** Misses a second user on a host with craftapps on.
- **Change nix-craftapps** to set defaults upstream. Out of scope by the intent, and the video and audio choice is
  local policy.

## Risks

- **`mkForce` hides a later default** for one of these types elsewhere. The mapping is in one file and named in
  the docs; a host that wants something else turns the app off.
- **#2837 was another session's change.** This spec removes its host blocks and keeps its outcome (PDF in
  PdfCraft). The PR names #2837.
- **Open file managers** may need a restart to pick up the new list.
- **"Set as default" in a file manager** does not stick for these types. Unchanged from today: `gnome/apps.nix`
  already makes Home Manager own `~/.config/mimeapps.list`.
- **razer** builds on p620 (`just deploy-via-p620 razer`).

## Verification

- `just test-host p620`, and razer's toplevel built on p620, succeed with both guards.
- Each guard fails when it should: mapping a type no app declares fails the check, and mapping one type under two
  apps fails the assertion. Revert both.
- `nix eval` of `home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications` on p620: exactly one entry, the
  Craft app's, for `application/pdf`, `image/png`, `image/svg+xml`, `image/heic`; `video/mp4`, `audio/flac` and
  `text/markdown` unchanged. On p510, `application/pdf` is still Evince.
- The same eval with `features.craftapps.apps.vectorcraft = false`: no forced SVG entry, and
  `associations.removed."image/svg+xml"` lists FigCraft.
- After deploy on p620 and razer, `xdg-mime query default` gives the table's app for a sample per row (`.docx`,
  `.xlsx`, `.pptx`, PDF, PNG, HEIC, a raw type, SVG, `.ai`, IDML, DXF, `application/x-filmcraft`) and the old app
  for `video/mp4`, `audio/flac`, `text/markdown`, `application/vnd.ms-excel`.
- `xdg-open` on a sample PDF and PNG opens PdfCraft and PhotoCraft.
