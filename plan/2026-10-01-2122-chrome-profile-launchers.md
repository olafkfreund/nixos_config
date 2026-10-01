---
status: approved
issue: 2122
spec: spec/2026-10-01-2122-chrome-profile-launchers.md
---

# Plan: launcher entries per Chrome profile

## Approved decisions

- New Home Manager module `home/desktop/chrome-profiles.nix` declaring
  `programs.chromium.profileLaunchers`: `attrsOf (submodule { directory : str;
  picture : bool = false; })`, default `{ }`. The attribute name is the label.
- Each entry becomes `xdg.desktopEntries."chrome-profile-<slug>"`, where
  `<slug>` = label lower-cased with `.` replaced by `-` (`google-com`,
  `synechron`, `freundcloud-com`).
  - `name = "Chrome — <label>"`
  - `exec = "${lib.getExe' cfg.finalPackage "google-chrome-stable"} --profile-directory=\"<directory>\" %U"`
    (`finalPackage` carries the host's `commandLineArgs`; do not use
    `cfg.package` or a bare PATH lookup)
  - `icon` = `"${config.home.homeDirectory}/.config/google-chrome/<directory>/Google Profile Picture.png"`
    when `picture`, else `"google-chrome"`
  - `categories = [ "Network" "WebBrowser" ]`; no `mimeType`
  - `type = "Application"`, `terminal = false`
- Config guarded by `mkIf (cfg.enable && cfg.profileLaunchers != { })`, where
  `cfg = config.programs.chromium`.
- Mappings:

  | label           | p620        | razer       | picture |
  | --------------- | ----------- | ----------- | ------- |
  | google.com      | `Default`   | `Profile 2` | true    |
  | Synechron       | `Profile 3` | `Profile 3` | false   |
  | freundcloud.com | `Profile 4` | `Profile 5` | true    |

- p510 gets no mapping. Hyprland window class unchanged (accepted).

## Steps

1. `home/desktop/chrome-profiles.nix` (new): write the module above in the
   repo's module shape (`{ config, lib, ... }:`, `with lib; let cfg = ...; in`).
   → verify by `nix-instantiate --parse home/desktop/chrome-profiles.nix`.
   Traps: minimal comments (one line on why `finalPackage`, nothing that
   narrates code); no `mkIf cond true`.

2. `home/desktop/default.nix:5`: add `./chrome-profiles.nix` to `imports`
   after `./terminal-apps-desktop-entries.nix`.
   → verify by `just check-syntax`.
   Traps: explicit imports only, no `readDir`. This file is imported for every
   host via `Users/common/imports.nix:12`, so the empty default must yield no
   config on p510.

3. `Users/olafkfreund/p620_home.nix:93-111`: inside the existing
   `programs.chromium = { ... };` block, after `commandLineArgs`, add
   `profileLaunchers` with the p620 column.
   → verify by listing the three ids and checking each `exec` names the
   right directory:

   ```bash
   nix eval --json \
     .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.xdg.desktopEntries \
     | jq 'with_entries(select(.key | startswith("chrome-profile-"))) | map_values(.exec)'
   ```

   Traps: keep the existing `lib.mkForce` lines untouched.

4. `Users/olafkfreund/razer_home.nix:63-71`: same inside razer's
   `programs.chromium` block, razer column.
   → verify by the step 3 eval against `razer`.
   Traps: none beyond step 3.

## Tests

- `just check-syntax` passes.
- `just test-host p620` and `just test-host razer` build. razer may be built
  on p620 (`nixos-rebuild build --build-host olafkfreund@p620`) if heavy.
- Eval `nixosConfigurations.p510.config.home-manager.users.olafkfreund.xdg.desktopEntries`
  contains no `chrome-profile-*` key.
- After the PR merges and p620 is switched from `main`:
  `ls ~/.local/share/applications/chrome-profile-*` shows three files;
  `desktop-file-validate` passes on each; `gtk-launch chrome-profile-freundcloud-com`
  opens a window in that profile.
- Same on razer after `just deploy-via-p620 razer`.

## Rollback

Revert the PR's merge commit and switch the host. The module only adds
desktop files; removing it removes them. Chrome profiles are never touched.

## Execution notes

- Four file-editing steps, so per the managed model split the `coder` agent
  implements steps 1-4; the session model reviews with a fresh Opus agent
  given this plan and `git diff`.
- Work stays in the `../nixos-2122` worktree. Never check out the branch in
  `~/.config/nixos`.
- Deploying is not part of this plan's implementation: switch hosts only from
  `main` after merge, announcing on the agent bus first (AGENTS.md rule 6).
  p510 is not deployed.
