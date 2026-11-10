---
status: draft
issue: 2838
spec: spec/2026-11-10-2838-craftapps-default-apps.md
coders:
  1: coder # Nix module logic with a large literal table; needs care with priorities
  2: coder # two small host-block deletions and a docs page, in the same pass as step 1
reviewers:
  - codex # a second read of the mkForce, associations.removed and assertion logic
  - agy # it listed every MIME string in the spec review; checks the table against the desktop files again
---

# Plan: make the Craft apps the default applications for their file types

Branch `feat/2838-craftapps-default-apps`, worktree `~/.config/nixos-2838`.

## Approved decisions

1. All logic lives in `modules/desktop/craftapps.nix`. The #2837 PDF blocks in `hosts/p620/configuration.nix`
   (`:500-506`, comment plus `home-manager.sharedModules`) and `hosts/razer/configuration.nix` (`:322-327`) are
   deleted.
2. A `defaults` attrset, app → list of exact MIME strings, copied from the spec's table (the spec has the full
   strings; copy them, do not retype from memory). Types left out: WordCraft's `text/markdown`, `text/x-tex`,
   `text/html`; FilmCraft's video and SoundCraft's audio types; types owned by another Craft app.
3. Under `lib.mkIf cfg.enable`, one `home-manager.sharedModules` entry:
   - `xdg.mimeApps.enable = true`;
   - for every type of every **enabled** app,
     `xdg.mimeApps.defaultApplications.<type> = lib.mkForce [ "<desktopId>.desktop" ]`.
   `desktopId` comes from `lib.importJSON "${inputs.nix-craftapps}/apps.json"` (`.<app>.desktopId`), which
   `craftapps.nix` already reads for `names`.
4. For each **disabled** app, for each of its types, `xdg.mimeApps.associations.removed.<type>` lists the desktop
   files of every enabled Craft app that also declares that type. "Also declares" comes from a second literal
   attrset, `alsoClaimed`: type → apps, for the shared types only. From the spec:
   - `image/png`, `image/jpeg`: lightcraft, figcraft, vectorcraft;
   - `image/tiff`, `image/webp`: lightcraft, vectorcraft;
   - `image/gif`, `image/bmp`: vectorcraft;
   - `image/svg+xml`: figcraft;
   - `application/pdf`: vectorcraft;
   - `image/vnd.dxf`: vectorcraft.
   The step-1 check verifies this attrset too.
5. A NixOS `assertions` entry: no type appears under two apps in `defaults`.
6. One `system.checks` derivation, `pkgs.runCommand "craftapps-mime-check"`. For each enabled app it reads
   `${cfg.apps.<app>.package}/share/applications/<desktopId>.desktop` (the upstream option
   `programs.craftapps.apps.<app>.package`). It turns the `MimeType=` value into `;a;b;…;` and requires
   `;<type>;` for every type in `defaults.<app>` and every `alsoClaimed` entry naming that app. On a miss it prints
   the app and type, then fails.
7. `home/desktop/gnome/apps.nix` and `home/desktop/evince/default.nix` are not edited.

## Steps

1. **`modules/desktop/craftapps.nix`** (36 lines today): decisions 2–6. Keep the existing options and the
   `programs.craftapps` block as they are; add the new attrsets in the `let` and the new config next to the
   existing `programs.craftapps` assignment, inside `lib.mkIf cfg.enable`. Use `lib.mkMerge` with
   `lib.mapAttrsToList`/`lib.genAttrs`. Never `builtins.readFile` a package output at eval time
   (import-from-derivation); the check reads the desktop files at build time only.
   → verify: this prints one Craft entry for the first four types, and the existing player and editor for the
   last two:

   ```bash
   nix eval --json \
     .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.xdg.mimeApps.defaultApplications |
     jq '."application/pdf", ."image/png", ."image/svg+xml", ."image/heic", ."video/mp4", ."text/markdown"'
   ```

   Traps: `cfg.apps.<app>` is a bool here (our wrapper); the upstream per-app package is
   `config.programs.craftapps.apps.<app>.package`. Explicit imports only. No `mkIf cond true`.
2. **Host blocks and docs.**
   - Delete the `# PdfCraft opens and edits PDFs…` comment and its `home-manager.sharedModules` block in
     `hosts/p620/configuration.nix` and `hosts/razer/configuration.nix`. Remove `lib` from the file's arguments
     only if nothing else uses it.
   - Add `docs/applications/craftapps.md`: which types open in which app, what stays on video and audio
     players, how to turn an app off, and that `modules/desktop/craftapps.nix` owns the mapping.
   - Add the page to both `mkdocs.yml` and `mkdocs-full.yml`, next to `applications/herdr.md`.
   → verify: `nix eval` of `.#nixosConfigurations.razer…defaultApplications."application/pdf"` is exactly
   `["ai.storyteller.pdfcraft.desktop"]` (one entry, not two); `markdownlint-cli2 docs/applications/craftapps.md`.
   Traps: the nav must land in both mkdocs files; a line starting with `#2837` becomes a heading.
3. **Ship (Claude).**
   - Build the p620 toplevel and razer's toplevel on p620. Prove each guard by a temporary edit, then revert:
     - a type no app declares fails the check;
     - one type under two apps fails the assertion.
   - Evaluate with `features.craftapps.apps.vectorcraft = false`: there is no forced SVG entry, and
     `associations.removed."image/svg+xml"` lists FigCraft.
   - Evaluate p510: `application/pdf` is still Evince.
   - Opus review on `git diff main`, plus Codex and agy (`reviewers:`).
   - Open the PR, naming #2837.
   - Bus announcement, deploy p620, then `just deploy-via-p620 razer`.
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

The first 12 show the intent table's Craft app. The last 4 show what they show today: Totem, GNOME Music, VS Code
and LibreOffice Calc. Then `xdg-open` a sample PDF and a sample PNG: PdfCraft and PhotoCraft open.

## Rollback

Revert the merge commit and redeploy p620 and razer. The revert brings back #2837's PDF blocks, so PDF stays on
PdfCraft and the other types go back to eog, Evince and the MIME cache.
