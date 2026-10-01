---
status: draft
issue: 2122
intent: intent/2026-10-01-2122-chrome-profile-launchers.md
---

# Spec: launcher entries per Chrome profile

Decisions carried from the approved intent's open questions: icons are the
profile's Google account picture where Chrome stores one, the Chrome icon
otherwise; Hyprland not distinguishing the three windows is accepted.

## Design

One new Home Manager module, `home/desktop/chrome-profiles.nix`, imported by
path from `home/desktop/default.nix` (which `Users/common/imports.nix`
already imports for every host).

It declares one option:

```nix
programs.chromium.profileLaunchers = mkOption {
  type = attrsOf (submodule {
    options = {
      directory = mkOption { type = str; };          # e.g. "Profile 4"
      picture   = mkOption { type = bool; default = false; };
    };
  });
  default = { };
};
```

The attribute name is the label shown in the launcher. For each entry the
module emits `xdg.desktopEntries."chrome-profile-<slug>"`:

- `name = "Chrome — <label>"`
- `exec = "${getExe' cfg.finalPackage "google-chrome-stable"} --profile-directory=\"<directory>\" %U"`
  — `programs.chromium.finalPackage` is the package Home Manager already
  built with the host's `commandLineArgs` (verified on razer: its
  `bin/google-chrome-stable` contains `--use-angle=vulkan`), so the host
  flags apply exactly as for the stock launcher.
- `icon` = `${config.home.homeDirectory}/.config/google-chrome/<directory>/Google Profile Picture.png`
  when `picture = true`, otherwise `"google-chrome"`.
- `categories = [ "Network" "WebBrowser" ]`, `mimeType` unset (the stock
  `google-chrome.desktop` stays the http/https handler).

The whole config is `mkIf (cfg.enable && cfg.profileLaunchers != { })`, so
p510 and any host without the mapping get nothing.

Per-host mapping, set next to the existing `programs.chromium` block:

`Users/olafkfreund/p620_home.nix`

| label           | directory   | picture |
| --------------- | ----------- | ------- |
| google.com      | `Default`   | true    |
| Synechron       | `Profile 3` | false   |
| freundcloud.com | `Profile 4` | true    |

`Users/olafkfreund/razer_home.nix`

| label           | directory   | picture |
| --------------- | ----------- | ------- |
| google.com      | `Profile 2` | true    |
| Synechron       | `Profile 3` | false   |
| freundcloud.com | `Profile 5` | true    |

Pictures verified present on disk for every `true` row on both hosts.

## Alternatives rejected

- **Hard-coded entries in each host file.** Six near-identical desktop
  entries; the module removes the duplication for one small option.
- **`--profile-email=`.** Survives a profile being renumbered, but Synechron
  is not signed in and has no email, so it cannot cover all three.
- **`exec = "google-chrome-stable ..."` from PATH.** Works today, but
  depends on PATH order in the launcher's environment; `finalPackage` is the
  same binary without that dependency.
- **Copying the account pictures into the Nix store.** They live in `$HOME`
  and change when the account picture changes; a store copy would go stale
  and a missing file would fail the build.
- **Per-profile window class for Hyprland (`--class`).** Out of scope per
  the intent.

## Risks

- **Renumbered profile.** If a profile is deleted and recreated, its
  directory changes and the launcher opens a new empty profile. Fix is one
  line in the host file. Low likelihood.
- **Missing picture.** If the picture file disappears, the launcher shows a
  generic icon; nothing fails.
- **Name collision.** Entry ids are `chrome-profile-<slug>`; Chrome's own
  PWA launchers are `chrome-<appid>-<Profile>.desktop`, so no overlap.
- Home Manager change only, on p620 and razer. No system service touched.

## Verification

1. `just check-syntax`, then `just test-host p620` and
   `just test-host razer` build.
2. Eval each host's
   `home-manager.users.olafkfreund.xdg.desktopEntries` and confirm three
   `chrome-profile-*` entries with the directories from the tables.
3. After switching p620: `ls ~/.local/share/applications/chrome-profile-*`
   shows three files; `desktop-file-validate` passes on each; launching each
   (`gtk-launch chrome-profile-freundcloud-com`) opens a window in that
   profile (checked by the profile avatar in the toolbar).
4. razer: same check after `just deploy-via-p620 razer`.
