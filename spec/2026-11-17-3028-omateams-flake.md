---
status: approved
issue: 3028
intent: intent/2026-11-17-3028-omateams-flake.md
---

# Spec: Install omateams from the olafkfreund/omateams flake

## Owner decisions (from the intent approval)

- **Track the fork's default branch.** `flake.lock` pins the commit, and
  updating is `nix flake update omateams`.
- **Accept the extra closure** (one more QtWebEngine) until our nixpkgs
  reaches QtWebEngine 6.140.0.

## Design

### Input (`flake.nix`)

Add it next to `omapod` (line 150), with a comment in the same style:

```nix
# omateams: Microsoft Teams web in an Omarchy-themed window, from our fork;
# hosts/common/nixos/omarchy-omateams.nix (#3028). nixpkgs-qt is not followed:
# it pins QtWebEngine 6.140.0 (QTBUG-142040) until our nixpkgs has it.
omateams = {
  url = "github:olafkfreund/omateams";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
```

- Not following `nixpkgs-qt` keeps the Qt fix even though `nixpkgs` follows
  ours. If it ever did follow, the fork's Qt version check would fail the
  build loudly.
- `inputs` already reaches NixOS and home-manager modules
  (`flake.nix:403-404`, `:457-464`).

### Host module (`hosts/common/nixos/omarchy-omateams.nix`)

```nix
{ config, inputs, pkgs, ... }:
let
  # The fork's package, with the host's Hyprland on its PATH.
  omateams = inputs.omateams.packages.${pkgs.stdenv.hostPlatform.system}.omateams.override {
    hyprland = config.programs.hyprland.package;
  };
in
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    imports = [ inputs.omateams.homeManagerModules.default ];
    programs.omateams = {
      enable = true;
      package = omateams;
    };
    local.omarchy.enableOnce = [ "omateams" ];
  };
}
```

- **What it replaces.** The fork's home-manager module now sets
  `home.packages`, and also `programs.nixarchy.plugins.omateams.src`, which
  it sets because nixarchy's home-manager option is declared for this user.
  The host no longer sets either.
- **Header comment.** It says how to update: `nix flake update omateams`,
  not a rev bump.
- **Unchanged:** the enable-once hook and the user's name.

### omaoutlook (`hosts/common/nixos/omarchy-omaoutlook.nix`)

- `omateams` becomes
  `config.home-manager.users.olafkfreund.programs.omateams.package`.
- omaoutlook's substituted Teams path is then the exact store path the user
  runs, and Hyprland is passed to it as today.

### Remove the local package (`pkgs/`)

- Delete `pkgs/omateams/`.
- In `pkgs/default.nix`, drop the `omateams` line (`:56`).
- Change `omaoutlook` (`:59`) to
  `pkgs.callPackage ./omaoutlook { omateams = null; }`, with a one-line
  comment: the host module supplies omateams. Only that override is ever
  built; a bare build would fail on the null path, which is correct.

### Testing before the fork's PR merges

olafkfreund/omateams#2 isn't merged yet, so builds use
`--override-input omateams github:olafkfreund/omateams/feat/nix-flake`.
`flake.lock` is written against the default branch only after #2 merges. The
PR here merges after that.

## Alternatives rejected

- **Pinning a rev in the URL:** the owner chose to track the branch.
- **Using the fork's overlay:** the host modules call packages directly, as
  with omapod, so there is one way to get it.
- **Keeping `programs.nixarchy.plugins.omateams.src` in the host as well:**
  that would be two definitions of one option. The module already sets it,
  and the verification checks it.
- **Following `nixpkgs-qt`:** that brings back `6.140.0-rc`, which the fork
  refuses to build.
- **A second `.override` in `omarchy-omaoutlook.nix`:** it could drift from
  the user's package. Reading the user's option keeps them identical.

## Risks

- **The plugin `src` isn't set** if nixarchy's home-manager option isn't
  declared for this user. Mitigation: verification evaluates it. If it's
  missing, set it in the host module as before.
- **`omaoutlook` evaluated without its override,** for example by a future
  check of every custom package, fails on the null path. Today only the host
  module builds it.
- **Closure.** One more QtWebEngine is accepted until our nixpkgs catches up.
  Dropping `nixpkgs-qt` in the fork is a later change.
- **The old host keeps running after the switch.** The sign-in path is
  unchanged (`~/.local/share/omateams`), so it survives. But the old and new
  packages both say version 1.4.1, and `Service.qml` replaces a hidden host
  only when the versions differ. So a switch alone leaves the old,
  unguarded host process running.
  - Verification restarts it explicitly.
  - Bumping the fork's `manifest.json` to 1.4.2 would make the restart
    automatic. That is a fork change, and out of scope here.

## Verification

While olafkfreund/omateams#2 is open, every command takes
`--override-input omateams github:olafkfreund/omateams/feat/nix-flake`.

- **Evaluate** the plugin source for both hosts:

  ```bash
  nix eval --raw .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src
  nix eval --raw .#nixosConfigurations.razer.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src
  ```

  Both must be `<fork package>/share/omateams/plugin`.
- **Build** each host's `config.system.build.toplevel` with `nix build`.
  Then, for the omateams in each closure (`nix-store -qR result | grep -- '-omateams-'`):
  - **One package.** Exactly one omateams path, and it is the fork's
    (`nix eval` of `programs.omateams.package` gives the same path).
  - **Qt.** `ldd <pkg>/bin/.omateams-wrapped` lists only
    `qtwebengine-6.140.0`.
  - **Memory cap.** `<pkg>/bin/omateams` contains `MemoryHigh=12G`,
    `MemoryMax=16G` and `MemorySwapMax=0`, plus the unscoped `exec`
    fallback.
  - **Hyprland on `PATH`.** The Qt wrapper `<pkg>/bin/omateams-unscoped`
    puts the host's `config.programs.hyprland.package` on `PATH` (grep for
    its store path).
  - **Packaged files.**
    - `share/applications/omateams.desktop` and the icon exist.
    - `share/omateams/plugin/ui/BarWidget.qml` has the
      `(Color.bar && Color.bar.background) || "transparent"` fallback.
    - `ui/Service.qml` has `checkInstalled()` instead of `ensureHost()`,
      and points at `<pkg>/bin/omateams`.
    - `install.sh` is absent.
  - **omaoutlook.** Its `Main.qml` is compiled into the binary, so the check
    looks there: the `<pkg>/bin/omateams` path is found in
    `<omaoutlook>/bin/.omaoutlook-wrapped`, either as UTF-8 or as UTF-16.
- **Gone.** `test ! -e pkgs/omateams`, and a grep of the `.nix` files for
  `customPkgs.omateams`, `pkgs/omateams` and `./omateams` finds nothing.
- **Runtime on p620,** after the owner OKs switching the host:
  1. Restart omateams: `omateams quit`, then let the bar start it again, or
     run `omateams --hidden`.
     `readlink -f /proc/<pid from omateams status>/exe` must be the fork
     package's `.omateams-wrapped`.
  2. Teams is still signed in, the bar widget shows, and the restarted host
     is hidden.
  3. `omateams status` shows `captured: false` and has the new `overdue`
     field. That field only exists with the guard, so this proves the
     guard is running.
  4. The scope: `systemctl --user show` on the host's `run-*.scope` shows
     `MemoryHigh` 12G, `MemoryMax` 16G and `MemorySwapMax` 0.
  5. Share and stop 3 times. Expect no `eglCreateSync failed` in
     `journalctl --user`. Either `hostMemory` stays bounded, or the guard
     restarts the process with a "Teams restarted" notice; both are
     acceptable outcomes.
  6. A Teams link opened from omaoutlook opens in omateams.
  7. With `runInBackground` off in the shell UI, after `omateams quit` and a
     shell reload, the host doesn't start. Then turn it back on.
  8. The plugin stays enabled, and the enable-once hook doesn't re-enable a
     plugin the user turned off. This is the hook's existing behaviour, with
     its marker unchanged.
- **Runtime on razer:** after the owner's OK for a switch and a restart,
  Teams starts, is signed in, and shows the bar widget, and the running exe
  is the fork's package.

## Open questions

None. The intent's two questions were settled at approval.
