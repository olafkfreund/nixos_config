---
status: draft
issue: 3191
intent: intent/2026-11-23-3191-sddm-follows-theme.md
---

# Spec: the SDDM login screen follows the Omarchy theme

## Decisions on the intent's open questions

The intent was approved without answers, so this spec takes a default for each. Change any of them at this
review.

1. **When:** live. The next greeter after a theme change uses it, with no rebuild.
2. **Wallpaper:** shown. The theme's current background sits behind the form. A wallpaper-only change
   (`omarchy-theme-bg-set` and friends run no hook) is picked up at the next theme set or the next login, not
   at once.
3. **Logo and failed state:** the logo is tinted to the theme's accent. The lock icon, field frame and bullets
   use the theme's foreground. A wrong password uses the theme's red.
4. **Where:** in nixarchy, on by default whenever `programs.nixarchy.user` is set, with an option to turn it
   off. This repo only bumps the pin.
5. **Whose theme:** `programs.nixarchy.user`'s, and only that user's. Unset means today's look.
6. **`omarchy-refresh-sddm`:** runs the same sync once, then says what it did.

## Design

The greeter keeps loading the theme from the Nix store. Only two things in it come from outside the store,
through symlinks to a directory the desktop user owns. A hook that runs as that user on every theme change
fills that directory. No root helper, no polkit rule, no mutable QML.

```mermaid
flowchart LR
  A[omarchy theme set] --> B[theme-set.d hook, as the user]
  P[login: post-boot.d hook] --> B
  B -->|validated colours| C[/var/lib/nixarchy-greeter/theme.conf/]
  B -->|copied image| D[/var/lib/nixarchy-greeter/background/]
  C -. theme.conf.user symlink .-> E[SDDM omarchy theme, in the store]
  D -. background symlink .-> E
```

### 1. The SDDM theme (nixarchy package, `share/sddm/themes/omarchy`)

- **`theme.conf`** gains today's look as defaults:
  - `background=#1a1b26`
  - `foreground=#a9b1d6`
  - `accent=#9ece6a`
  - `failed=#f7768e`

  These are the colours of today's PNG images, so an unthemed greeter looks as it does now. The plan confirms the
  exact values from the PNG images.
- **`theme.conf.user`** is a symlink to `/var/lib/nixarchy-greeter/theme.conf`. SDDM 0.21 reads
  `<ConfigFile>.user` after the theme's own file; the `.user` lookup is in `sddm-greeter-qt6`. A missing
  target means no overrides.
- **`background`** is a symlink to `/var/lib/nixarchy-greeter/background`.
- **`Main.qml`**:
  - **Colours:** each one is read through one helper that accepts only `#rrggbb` and otherwise returns the
    default. A bad value cannot make the colour invalid.
  - **Wallpaper:** an `Image` of `background`, with `PreserveAspectCrop` and `asynchronous`, behind the
    existing form. It shows only when `status === Image.Ready`, so a missing or broken image leaves the
    colour.
  - **Recolouring:** the logo, lock, field frame and bullets are recoloured with `MultiEffect` from
    `QtQuick.Effects`, using the PNG's alpha as the shape and the chosen colour as the fill. This works for
    any source luminance; plain colorization keeps luminance, and dark sources stay dark. `QtQuick.Effects`
    ships in qtdeclarative 6.12, which is already on the greeter's QML path.
  - **Wrong password:** the failed state switches the colour to `failed`, instead of the `*-failed.png`
    images.
  - **Legibility:** over the wallpaper, the form keeps a translucent panel in the background colour, so the
    field stays readable on a busy or light image.

### 2. The directory (nixarchy NixOS module)

When `programs.nixarchy.user` is set and the new option `programs.nixarchy.greeterFollowsTheme` (default
`true`) is on, a `systemd.tmpfiles` rule creates `/var/lib/nixarchy-greeter`:

- owned by that user;
- group `root`, mode `0755`, so the `sddm` user can read it and nobody else can write it.

Otherwise no directory exists. The symlinks then dangle, and the greeter shows today's look.

### 3. The sync (nixarchy Home Manager module)

`nixarchy-greeter-sync` is a packaged script, installed as:

- `~/.config/omarchy/hooks/theme-set.d/20-greeter`, the same extension point as nixarchy's `cursor` and
  `10-owe-sync` hooks;
- `~/.config/omarchy/hooks/post-boot.d/20-greeter`, so a login syncs the theme that is already active,
  including the first one.

It runs as the user and does this:

1. Exit 0 without changes if `/var/lib/nixarchy-greeter` is missing or not writable. A theme switch never
   fails over the greeter.
2. Read `background`, `foreground`, `accent` and `red` from
   `~/.local/state/omarchy/current/theme/colors.toml`. Keep only values matching `^#[0-9a-fA-F]{6}$`; anything
   else is left out, and the greeter falls back to the default for it.
3. Write `theme.conf` (`[General]` and those keys) to a temporary file in the same directory, then `mv` it
   into place, so the greeter never reads half a file.
4. Resolve `~/.local/state/omarchy/current/background`. If it is a regular file with a PNG or JPEG extension
   and is at most 25 MB, copy it to a temporary file and `mv` it to `background`. Anything else, including a
   video background or no background, removes `background`, and the greeter shows the colour.
5. Copy only those two files. The script reads the user's own files, so it gains nothing by following a
   symlink in them. Nothing privileged reads the home directory.

### 4. `omarchy-refresh-sddm`

nixarchy's NixOS stub runs `nixarchy-greeter-sync` and prints whether the next login screen will use the
theme, or why not (the option is off, or the directory is missing).

### 5. This repo

Bump the nixarchy pin. All three hosts already set `programs.nixarchy.user = "olafkfreund"`, so the feature is
on with no host change.

## Alternatives rejected

- **Recolour at rebuild through Stylix,** like Plymouth and GRUB: it needs a rebuild after every theme change.
  The rest of a theme change is live.
- **A root service, path unit or polkit-allowed unit** that copies the theme out of the user's home: it adds a
  privileged reader of user-controlled files (the symlink risk) for data the user can write themselves.
- **Point `ThemeDir` at a mutable directory:** the greeter would then run QML the user can edit. That is code
  as the `sddm` user, not data.
- **A generated QML file loaded with `Loader`,** or reading the file with `XMLHttpRequest`: the same code
  problem, or it needs `QML_XHR_ALLOW_FILE_READ` set in the greeter's environment.
- **Only in this repo:** nixarchy ships the theme, and every nixarchy user has the same mismatch.

## Risks

- **A QML error stops the greeter:** for example a `QtQuick.Effects` import that fails, or a typo. SDDM gives
  up after six failed starts, which leaves a host with no login manager. Mitigation:
  - a nixarchy VM check that boots to the greeter, once with no theme data and once with a theme and a
    wallpaper, and takes a screenshot of each;
  - razer is deployed before p620;
  - the rollback is the previous generation, chosen at boot.
- **A large wallpaper** slows the greeter's first frame. The 25 MB cap and `asynchronous` loading keep it off
  the critical path, and a decode failure shows the colour.
- **Another user on a multi-user machine** sees `programs.nixarchy.user`'s wallpaper on the login screen. This
  is documented on the option. Users who don't want it set it to `false`.
- **The user can write anything into `/var/lib/nixarchy-greeter`.** The greeter reads only `#rrggbb` strings
  and one image from it, and a bad image means no image.
- **Edge and stable pins:** nixarchy main builds Omarchy v4.5.0 and edge builds quattro. The SDDM theme
  differs between the two, so the change is built and checked under both pins.
- **p510:** built and deployed only with the owner's OK.

## Verification

- **nixarchy:** `nix build .#omarchy` under both pins.
  - New VM check: no theme data gives today's colours. A theme with a wallpaper gives the theme's colours and
    the image. A bad value in `theme.conf` (for example `background=red;`) still shows the default, and login
    still works.
  - Existing checks pass.
- **Sync script:** a shell test over fixtures covers:
  - a valid theme;
  - bad hex values;
  - a missing `colors.toml`;
  - a video background;
  - an oversized image;
  - a directory that is missing or not writable (the script exits 0 and changes nothing);
  - output that is only ever replaced whole.
- **This repo:**
  - `just test-host p620` and `just test-host razer`.
  - Deploy razer, then p620. On each:
    - `omarchy theme set` to a light theme and to a dark theme;
    - log out: the greeter shows the theme's colours and wallpaper;
    - a wrong password shows the theme's red;
    - log back in.
  - p510 only with the owner's OK.
