---
status: draft
issue: 2838
spec: spec/2026-11-10-2838-craftapps-default-apps.md
coders:
  1: coder # Nix module logic with a large literal table, plus the two host-block deletions
  2: coder # the docs page and its nav entries
reviewers:
  - codex # a second read of the mkForce, associations.removed and assertion logic
  - agy # it listed every MIME string in the spec review; checks the table against the desktop files again
---

# Plan: make the Craft apps the default applications for their file types

Branch `feat/2838-craftapps-default-apps`, worktree `~/.config/nixos-2838`.

## Approved decisions

1. All logic lives in `modules/desktop/craftapps.nix`. The #2837 PDF blocks are deleted in the same step:
   `hosts/p620/configuration.nix:500-506` and `hosts/razer/configuration.nix:321-327` (the
   `# PdfCraft opens and edits PDFs…` comment and its `home-manager.sharedModules` list). Both files keep `lib`;
   they use it elsewhere.
2. A `defaults` attrset, app → list of exact MIME strings (copied from each desktop file, nix-craftapps
   `848f049f`). It holds exactly this:

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

   Apps not in this table (`effectcraft`, `craft-anything`) get nothing. Every code path iterates over `defaults`
   (or uses `defaults.${app} or [ ]`), never over all of `cfg.apps`. Deliberately absent: WordCraft's
   `text/markdown`, `text/x-tex`, `text/html`; FilmCraft's `video/*` and `application/mxf`; SoundCraft's `audio/*`;
   and each shared type under every app except its owner (decision 4).
3. Under `lib.mkIf cfg.enable`, one `home-manager.sharedModules` entry:
   - `xdg.mimeApps.enable = true`;
   - for every type of every **enabled** app in `defaults`,
     `xdg.mimeApps.defaultApplications.<type> = lib.mkForce [ "<desktopId>.desktop" ]`.

   `desktopId` comes from `lib.importJSON "${inputs.nix-craftapps}/apps.json"` (`.<app>.desktopId`, for example
   `ai.storyteller.photocraft`). `craftapps.nix` already reads that file for `names`. The source file is fine at
   eval time; package outputs are not.
4. `alsoClaimed`, type → the other Craft apps that declare it, for the shared types only (checked against the
   installed desktop files):
   - `image/png`, `image/jpeg`: lightcraft, figcraft, vectorcraft;
   - `image/tiff`, `image/webp`: lightcraft, vectorcraft;
   - `image/gif`, `image/bmp`: vectorcraft;
   - `image/svg+xml`: figcraft;
   - `application/pdf`: vectorcraft;
   - `image/vnd.dxf`: vectorcraft.

   For each **disabled** owner, each of its types listed in `alsoClaimed` gets
   `xdg.mimeApps.associations.removed.<type>`. That list holds the desktop files of the **enabled** apps from
   that entry.
5. A NixOS `assertions` entry: no type appears under two apps in `defaults`. The message names the type.
6. One `system.checks` derivation, `pkgs.runCommand "craftapps-mime-check"`; add `pkgs` to the module arguments.
   - For each enabled app in `defaults`, it reads
     `${config.programs.craftapps.apps.${app}.package}/share/applications/<desktopId>.desktop`. That is the
     upstream option: our wrapper's `cfg.apps.<app>` is only a bool.
   - It turns the `MimeType=` value into `;a;b;…;` and requires `;<type>;` for every type in `defaults.<app>`,
     and for every `alsoClaimed` entry that names the app.
   - On a miss it prints the app and the type, then fails.
7. `home/desktop/gnome/apps.nix` and `home/desktop/evince/default.nix` are not edited.

## Steps

1. **`modules/desktop/craftapps.nix` and the two host blocks** (decisions 1–6).
   - Keep the existing options and the `programs.craftapps` block. Put `defaults`, `alsoClaimed` and the
     `desktopId` lookup in the `let`, and the new config inside `lib.mkIf cfg.enable`, merged with
     `lib.mkMerge`.
   - Delete the two host blocks.
   → verify (all must print `true`):

   ```bash
   d='.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications'
   nix eval --json "$d" | jq -e '
     ."application/pdf" == ["ai.storyteller.pdfcraft.desktop"] and
     ."image/png" == ["ai.storyteller.photocraft.desktop"] and
     ."image/svg+xml" == ["ai.storyteller.vectorcraft.desktop"] and
     ."image/heic" == ["ai.storyteller.lightcraft.desktop"] and
     ."video/mp4" == ["org.gnome.Totem.desktop"] and
     ."audio/flac" == ["org.gnome.Music.desktop"] and
     (has("text/markdown") | not)'
   nix eval --json '.#nixosConfigurations.razer.config.home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications."application/pdf"'
   nix build --no-link .#nixosConfigurations.p620.config.system.checks
   ```

   The razer eval prints `["ai.storyteller.pdfcraft.desktop"]` (one entry). The last line builds the check.
   Traps: never `builtins.readFile` a package output at eval time (import-from-derivation). No
   `mkIf cond true`. Explicit imports only.
2. **Docs.**
   - Add `docs/applications/craftapps.md`. It covers which types open in which app, what stays on the video and
     audio players, how to turn an app off (`features.craftapps.apps.<app> = false`), and that
     `modules/desktop/craftapps.nix` owns the mapping.
   - Add the page to the nav after `applications/herdr.md` in `mkdocs.yml:200` and `mkdocs-full.yml:192`.
   → verify: `markdownlint-cli2 docs/applications/craftapps.md`, and
   `grep -c 'applications/craftapps.md' mkdocs.yml mkdocs-full.yml` prints 1 for each file.
   Traps: a line that starts with `#2837` becomes a heading.
3. **Ship (Claude).**
   - Merge `origin/main` into the branch. Run `just validate` and `just test-host p620`, then build razer's
     toplevel on p620:
     `nix build --no-link .#nixosConfigurations.razer.config.system.build.toplevel`.
   - Prove each guard with a temporary edit that is reverted before the commit:
     - map `image/x-not-real` under `pdfcraft`, and the check fails naming it;
     - add `application/pdf` under `vectorcraft` too, and the assertion fails.
   - Disabled owner (expect `{"forced":null,"removed":["ai.storyteller.figcraft.desktop"]}`):

     ```bash
     nix eval --impure --json --expr '
       let c = (builtins.getFlake "path:'"$PWD"'").nixosConfigurations.p620.extendModules {
             modules = [ { features.craftapps.apps.vectorcraft = false; } ]; };
           m = c.config.home-manager.users.olafkfreund.xdg.mimeApps;
       in { forced = m.defaultApplications."image/svg+xml" or null;
            removed = m.associations.removed."image/svg+xml" or null; }'
     ```

   - p510 is unchanged: evaluating
     `.#nixosConfigurations.p510.config.home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications."application/pdf"`
     prints `["org.gnome.Evince.desktop"]`. Evaluate only; no build.
   - Run an Opus review on `git diff origin/main...HEAD`, plus Codex and agy (`reviewers:`).
   - Open the PR, naming #2837, and merge it with the owner's OK.
   - From `~/.config/nixos` on `main`: post the bus announcement, deploy p620 (`just p620`), then
     `just deploy-via-p620 razer`.
   - Live check on both hosts (Tests). p510 is not built or deployed.

## Tests

On p620 and razer after deploy:

```bash
for t in application/vnd.openxmlformats-officedocument.wordprocessingml.document \
  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
  application/vnd.openxmlformats-officedocument.presentationml.presentation \
  application/pdf image/png image/heic image/x-canon-cr3 image/svg+xml application/illustrator \
  application/vnd.adobe.indesign-idml-package image/vnd.dxf application/x-filmcraft \
  video/mp4 audio/flac text/markdown application/vnd.ms-excel; do
  printf '%-70s %s\n' "$t" "$(xdg-mime query default "$t")"
done
```

- The first 12 types show the Craft app from decision 2.
- The last 4 show what they show today: Totem, GNOME Music, VS Code and LibreOffice Calc.
- `xdg-open` on a sample PDF opens PdfCraft, and on a sample PNG opens PhotoCraft.

## Rollback

Revert the merge commit and redeploy p620 and razer. The revert restores #2837's PDF blocks, so PDF stays in
PdfCraft. The other types go back to eog, Evince and the MIME cache.
