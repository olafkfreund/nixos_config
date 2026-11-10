---
status: draft
issue: 2838
intent: intent/2026-11-10-2838-craftapps-default-apps.md
---

# Spec: make the Craft apps the default applications for their file types

## Design

All logic goes in `modules/desktop/craftapps.nix`, our wrapper around `inputs.nix-craftapps.nixosModules.default`.
No other file changes behaviour.

### The mapping: one attrset, app → MIME types

A `defaults` attrset in `craftapps.nix` lists, per app, the types from the approved intent's table. Every type is
copied from that app's own `MimeType=` line (nix-craftapps rev `848f049f`):

- `wordcraft`: the OpenXML document, macro and template types, `application/msword`,
  `application/vnd.oasis.opendocument.text`, `application/rtf`, `text/rtf`. Not `text/markdown`, `text/html`,
  `text/x-tex`.
- `gridcraft`: the OpenXML sheet, macro and binary types, `application/vnd.oasis.opendocument.spreadsheet`,
  `text/csv`, `text/tab-separated-values`.
- `deckcraft`: `application/x-deckcraft` and the OpenXML presentation, template and slideshow types.
- `pdfcraft`: `application/pdf`.
- `photocraft`: `application/x-photocraft` and its raster and layered image types (PNG, JPEG, WebP, GIF, TIFF,
  BMP, AVIF, QOI, TGA, both icon types, the PNM family, EXR, Radiance, PSD, PSB, Krita, OpenRaster, Paint.NET).
- `lightcraft`: `image/heic`, `image/heif` and its camera raw types. Not PNG, JPEG, TIFF or WebP (PhotoCraft's).
- `vectorcraft`: `application/x-vectorcraft`, `-template`, SVG, compressed SVG, Illustrator and its template, EPS,
  EMF, WMF, Affinity. Not PDF, DXF or raster types.
- `figcraft`: `application/x-figcraft`, `application/x-sketch`, `x-scheme-handler/figcraft`. Not SVG or raster.
- `designcraft`: `application/x-designcraft`, `application/vnd.adobe.indesign-idml-package`.
- `cadcraft`: its DWG and DXF types.
- `filmcraft`: `application/x-filmcraft` only. `soundcraft`: `application/x-soundcraft-session` only.
- `effectcraft` and `craft-anything` declare no types and get none.

Each type appears under exactly one app, which settles the shared types as the intent's Open questions proposed.

### Where it lands: a Home Manager shared module, by priority

`craftapps.nix` adds, under `lib.mkIf cfg.enable`:

```nix
home-manager.sharedModules = [{
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = lib.mkMerge (lib.mapAttrsToList (app: types:
    lib.genAttrs types (_: lib.mkForce [ "${desktopId app}.desktop" ]))
    (lib.filterAttrs (app: _: cfg.apps.${app}) defaults));
}];
```

- `desktopId` comes from the flake input's `apps.json` (already read by `craftapps.nix` for the app names), for
  example `ai.storyteller.photocraft`.
- `lib.mkForce` per type: Home Manager concatenates `defaultApplications` lists of equal priority, so a plain
  definition would sit next to `org.gnome.eog.desktop` from `home/desktop/gnome/apps.nix` and the Evince line from
  `home/desktop/evince/default.nix`. At force priority only the Craft entry is kept, for those types only; every
  other type keeps its normal definitions. The repo already does this for one type
  (`hosts/common/nixos/omarchy-flea.nix:50`).
- `sharedModules` reaches every Home Manager user on the host. Today that is `olafkfreund` on p620 and razer. The
  upstream module already uses `home-manager.sharedModules` the same way for its MCP servers.
- An app set to `false` in `features.craftapps.apps` is filtered out, so its types keep the GNOME, Evince or
  MIME-cache default, as the intent requires.
- The GNOME and Evince modules are not edited: on p510, and on any host without craftapps, they apply as today.

### A build check that the mapping matches the apps

`craftapps.nix` adds one `system.checks` derivation (built with the system, no import-from-derivation). For each
enabled app it greps the app package's `share/applications/<desktopId>.desktop` `MimeType=` line for every type
mapped to it, and fails the build naming any type the app no longer declares. A nix-craftapps update that drops a
type then breaks `just test-host` instead of leaving a default to an app that cannot open it.

## Alternatives rejected

- **Generate the mapping from the desktop files.** Reading package output at eval time is import-from-derivation;
  and the shared types would still need a hand-written owner per type.
- **System-wide `xdg.mime.defaultApplications`** (`/etc/xdg/mimeapps.list`). Home Manager's
  `~/.config/mimeapps.list` wins over it, so PDF and images would stay on Evince and eog.
- **Edit `gnome/apps.nix` and `evince/default.nix`** to drop their lines or wrap them in `mkDefault`. That spreads
  the rule over three files and changes p510 and other hosts that do not run the Craft apps.
- **A per-user module in `Users/olafkfreund/`.** It would miss a second user added to a host with craftapps on.
- **Change nix-craftapps** to set defaults upstream. Out of scope by the intent's constraint, and the owner choice
  (video and audio stay on their players) is local policy.

## Risks

- **`mkForce` hides a later, deliberate default** for one of these types elsewhere in the repo. Mitigation: the
  mapping is in one file and named in `docs/`; a host that wants something else turns the app off or uses
  `mkOverride` below 50.
- **The desktop session caches associations.** File managers read `mimeapps.list` on change; an open Nautilus may
  need a restart to show the new default.
- **"Set as default" in a file manager** does not stick for these types. Unchanged from today: `gnome/apps.nix`
  already makes Home Manager own `~/.config/mimeapps.list`.
- **razer** builds on p620 (`just deploy-via-p620 razer`), as usual.

## Verification

- `just test-host p620` and `nix build .#nixosConfigurations.razer.config.system.build.toplevel` (through p620)
  succeed, including the new check.
- The check fails when a type is not declared: temporarily map a type no app declares and see the build fail with
  that type named, then revert.
- `nix eval` of `home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications` on p620 shows one entry per type,
  the Craft app's, for `application/pdf`, `image/png` and `image/svg+xml`. `video/mp4` and `text/markdown` are
  unchanged. On p510 the PDF entry is still Evince.
- After deploy on p620 (and razer), `xdg-mime query default` prints the intent table's app for a sample of each row:
  `.docx`, `.xlsx`, `.pptx`, PDF, PNG, HEIC, a raw type, SVG, `.ai`, IDML, DXF, `application/x-filmcraft`; and the
  old app for `video/mp4`, `audio/flac`, `text/markdown`, `application/vnd.ms-excel`.
- `xdg-open` on a sample PDF and PNG opens PdfCraft and PhotoCraft.
