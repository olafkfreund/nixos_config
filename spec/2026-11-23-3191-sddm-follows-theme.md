---
status: draft
issue: 3191
intent: intent/2026-11-23-3191-sddm-follows-theme.md
---

# Spec: the SDDM login screen follows the Omarchy theme

## Decisions on the intent's open questions

The intent was approved without answers, so this spec takes a default for each. Change any of them at this review.

1. **When:** live. The next greeter after a theme change uses it, with no rebuild.
2. **Wallpaper:** shown. The theme's current background sits behind the form.
   - A wallpaper-only change (`omarchy-theme-bg-set` and friends, which run no hook) is picked up at the next theme
     set or the next login, not at once.
   - So is a headless theme set (`THEME_HEADLESS=1` skips the `theme-set` hook).
3. **Logo and failed state:**
   - The logo is tinted to the theme's accent.
   - The lock icon and the field frame use the theme's foreground, and the bullets are drawn in it.
   - A wrong password turns the lock and frame to the theme's red until the next key press.
4. **Where:** in nixarchy, as an opt-in option, `programs.nixarchy.greeterThemeUser`. It follows nixarchy's
   `browserThemeUser`: naming the desktop user in `programs.nixarchy.user` must not, on its own, let them change what
   every user sees at login. This repo sets it to `olafkfreund` on all three hosts.
5. **Whose theme:** `greeterThemeUser`'s, and only that user's. Unset means today's look.
6. **`omarchy-refresh-sddm`:** asks for a publish now, then says whether the next login screen will use the
   theme, or why not.

## Design

The greeter reads only files that a hardened system service wrote. The user's side drops raw theme data into an
inbox. The service, triggered by a path unit, validates the data, re-encodes the wallpaper in its own sandbox, and
swaps in a complete new generation in one rename. The theme's QML loads anything new (the effects) through a
`Loader` that falls back to today's images, so a QML failure in the new part cannot stop the greeter.

```mermaid
flowchart LR
  A[theme-set.d hook] --> S[nixarchy-greeter-sync, as the user]
  P[post-boot.d hook] --> S
  S -->|colors.toml + wallpaper, then ready| I[/var/lib/nixarchy-greeter/inbox/]
  I --> U[path unit]
  U --> V[publish service, user nixarchy-greeter]
  V -->|validated theme.conf + PNG, one rename| C[/var/lib/nixarchy-greeter/out/current/]
  C -. theme.conf.user and background symlinks .-> G[SDDM omarchy theme, in the store]
```

### 1. The SDDM theme (nixarchy package, `share/sddm/themes/omarchy`)

v4.5.0 and quattro ship the same `Main.qml` today, so one change fits both pins.

- **`metadata.desktop`:** gains `ConfigFile=theme.conf`, instead of relying on SDDM's default.
- **`theme.conf`:** gains today's look as defaults, taken from today's PNG images in the plan:
  - `background`: `#1a1b26`, as now;
  - `foreground`;
  - `accent`: the logo's green;
  - `failed`: the red of the `*-failed.png` images.

  So an unthemed greeter looks as it does today.
- **Two symlinks:**
  - `theme.conf.user` points to `/var/lib/nixarchy-greeter/out/current/theme.conf`;
  - `background` points to `/var/lib/nixarchy-greeter/out/current/background.png`.

  SDDM 0.21 reads `<ConfigFile>.user` after the theme's own file; the `.user` lookup is in `sddm-greeter-qt6`. A
  missing target means no overrides and no image.
- **`Main.qml`** keeps its imports (`QtQuick`, `SddmComponents`) and the password field, Enter handling and focus as
  they are. Changes:
  - **Colours:** one helper reads each value from `config` and accepts only `#rrggbb`; anything else gives the
    built-in default.
  - **Wallpaper:** an `Image` of `background`, with `asynchronous: true`, `PreserveAspectCrop` and `sourceSize`
    bound to the screen size, behind the form. It shows only when `status === Image.Ready`. A translucent panel
    in the background colour sits behind the form so it stays legible.
  - **Bullets:** drawn as small `Rectangle`s in the foreground colour, with no effect per bullet.
  - **Logo, lock and field frame:** each is a `Loader` of a small component file in the theme, `Tinted.qml`. That
    file imports `QtQuick.Effects` and uses `MultiEffect` with the PNG's alpha as a mask over a solid colour, at the
    PNG's own size and alignment. If the `Loader` reports `Loader.Error`, a plain `Image` of today's PNG is shown
    instead, and the `*-failed.png` images for the failed state. `QtQuick.Effects` ships in qtdeclarative 6.12,
    which is on the greeter's QML path, but the fallback does not depend on that.
  - **Wrong password:** `onLoginFailed` clears the field first and then sets `loginFailed`. The flag resets on the
    next key press, not on the text change caused by the clear. Today's code sets the flag, and the clear's
    `onTextChanged` resets it at once, so the failed look never shows.

### 2. The NixOS module (nixarchy)

When `programs.nixarchy.displayManager` is on and `greeterThemeUser` is set:

- **The inbox:** `/var/lib/nixarchy-greeter/inbox`, from tmpfiles: owned by `greeterThemeUser`, mode `0755`.
  A `d` rule also corrects the owner when the user changes.
- **The publish output:** `/var/lib/nixarchy-greeter/out/current` and its generations, owned by a static system user
  `nixarchy-greeter`. The parent `/var/lib/nixarchy-greeter` is `root`, mode `0755`. The greeter (`sddm`) can read
  everything; the desktop user can write only the inbox.
- **`nixarchy-greeter-publish.path`:** `PathChanged=/var/lib/nixarchy-greeter/inbox/ready`.
- **`nixarchy-greeter-publish.service`,** a oneshot run as `nixarchy-greeter`. It is hardened per the repo
  pattern, with a static user instead of `DynamicUser`, because the greeter must traverse into its output and
  DynamicUser state sits under `/var/lib/private` (mode 0700). It has:
  - `ProtectSystem=strict`, `ProtectHome=true`, `NoNewPrivileges=true`;
  - `ReadWritePaths=/var/lib/nixarchy-greeter/out` only, and no network;
  - `MemoryMax` and `RuntimeMaxSec`, which bound a hostile image.

  It does this:
  1. Open each inbox file without following symlinks, and accept only regular files under a size cap: 64 KB for
     `colors.toml`, 50 MB for the image.
  2. Parse `background`, `foreground`, `accent` and `red` from `colors.toml`, keeping only `#rrggbb` values. Write
     `theme.conf` with `red` as `failed`.
  3. Decode the image with ImageMagick under resource limits, inside this service, and write
     `background.png` at most 3840×2160. Any failure gives a generation with no image.
  4. Write the new generation into `out/<timestamp>/`, with files mode 0644. Then point `current` at it with one
     atomic symlink rename, and delete older generations. The greeter sees the whole old pair or the whole new
     one, never a mix.
  5. Any failure leaves `current` as it was.
- **Turning it off:** setting `greeterThemeUser` back to null, or turning off `displayManager`, adds a tmpfiles `R`
  rule for `/var/lib/nixarchy-greeter`. NixOS runs tmpfiles with `--remove` on every switch, so the old theme does
  not linger. The theme's symlinks then dangle, which means today's look.

### 3. The sync (nixarchy Home Manager module)

`nixarchy-greeter-sync` is a packaged script. It is installed as `theme-set.d/20-greeter`, beside nixarchy's
`cursor` and `10-owe-sync` hooks, and as `post-boot.d/20-greeter`. Omarchy's `autostart.lua` calls `post-boot` at
every login on both pins. It runs as the user:

1. If the inbox is missing or not writable, exit 0. A theme switch never fails over the greeter.
2. Take `flock` on a lock file in `$XDG_RUNTIME_DIR`, so overlapping theme switches run one at a time and the
   last one wins.
3. Copy `~/.local/state/omarchy/current/theme/colors.toml`, and the file behind
   `~/.local/state/omarchy/current/background` when it is an image Omarchy accepts (png, jpg, jpeg, gif, bmp or
   webp; not a video), into the inbox. Each file goes to a temporary name, is set to mode 0644, and is then renamed
   into place. A video or missing background removes the inbox image.
4. Touch `inbox/ready` last, which triggers the publish.
5. A trap removes temporary files on exit.

A theme set that is still running when the user logs out can miss this greeter. The next login's `post-boot`
catches up.

### 4. `omarchy-refresh-sddm`

nixarchy's NixOS stub runs `nixarchy-greeter-sync` and then reports whether `nixarchy-greeter-publish.path` exists
(the option is on) and whether `current` changed.

### 5. This repo

- Bump the nixarchy pin.
- Set `programs.nixarchy.greeterThemeUser = "olafkfreund"` for p620, razer and p510.

## Alternatives rejected

- **Recolour at rebuild through Stylix,** like Plymouth and GRUB: it needs a rebuild after every theme change. The
  rest of a theme change is live.
- **The greeter reads a user-owned directory directly** (the first draft): the user could swap in a symlink, a FIFO
  or a huge image and hang or exhaust the greeter. That would be a login denial for every user of the machine.
- **A root service that reads the user's home:** a privileged reader of user-controlled paths. The inbox keeps the
  service out of `$HOME`, and the service is not root.
- **`DynamicUser` for the publish service:** its state sits under `/var/lib/private` (mode 0700), which the greeter
  cannot traverse.
- **Point `ThemeDir` at a mutable directory,** or load generated QML: the greeter would run code the user can edit.
- **Read the file from QML with `XMLHttpRequest`:** this needs `QML_XHR_ALLOW_FILE_READ` in the greeter's
  environment, and it still opens user files.
- **On by default whenever `programs.nixarchy.user` is set:** that contradicts nixarchy's own `browserThemeUser`
  reasoning on shared machines.
- **Only in this repo:** nixarchy ships the theme, and every nixarchy user has the same mismatch.

## Risks

- **A QML error stops the greeter.** SDDM gives up after six failed starts, which leaves a host with no login
  manager. Mitigation:
  - `Main.qml` adds no new imports;
  - the new effect code sits behind a `Loader` with a PNG fallback;
  - a nixarchy VM check logs in through the real greeter (below);
  - razer is deployed first;
  - the previous generation stays available at boot.
- **The publish service fails or is slow.** `current` stays as it was, so the greeter shows the last good theme or
  today's look. A hung decode is killed by `RuntimeMaxSec`.
- **On a shared machine, others see `greeterThemeUser`'s wallpaper.** This is documented on the option, which is
  opt-in.
- **The inbox fills `/var`.** Bounded by the size caps on what is published. The inbox is the user's own write, and
  only its latest two files are kept.
- **Edge and stable pins:** the theme files are the same on both today. The change is built and checked under both
  pins.
- **p510:** built and deployed only with the owner's OK.

## Verification

- **nixarchy:** `nix build .#omarchy` under both pins.
- **New VM check, through the real `sddm-greeter-qt6` under Hyprland as in `omarchy-sddm.nix`.** For each case it
  takes a screenshot, then types the password and checks that the session starts:
  - no theme data: today's colours and no image;
  - a theme with a wallpaper: the theme's colours and the image;
  - a bad `colors.toml` (`background = "red;"`): the default colour, and login works;
  - a FIFO, a symlink and a 60 MB file dropped into the inbox: the publish refuses them, `current` is unchanged,
    and login works;
  - `Tinted.qml` replaced with a broken one: the PNG fallback shows, and login works;
  - a wrong password: the red state shows after the field clears.
- **Sync script:** a shell test over fixtures covers a valid theme, a missing `colors.toml`, a video background,
  two overlapping runs, and a missing or read-only inbox (exit 0, no change).
- **This repo:**
  - `just test-host p620` and `just test-host razer`.
  - Deploy razer, then p620. On each:
    - `omarchy theme set` to a light theme and to a dark theme;
    - log out: the greeter shows the theme's colours and wallpaper;
    - a wrong password shows the theme's red;
    - log back in.
  - p510 only with the owner's OK.
