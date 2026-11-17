---
status: draft
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
- **Runtime.** The sign-in path is unchanged (`~/.local/share/omateams`), so
  it survives. The new host binary is version 1.4.1 with PR #1, and the
  plugin manifest says 1.4.1, so the plugin doesn't replace a running host.

## Verification

- **Evaluate,** with the override while #2 is open:

  ```bash
  nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src
  nix eval .#nixosConfigurations.razer.config.home-manager.users.olafkfreund.programs.nixarchy.plugins.omateams.src
  ```

  Both must end in `/share/omateams/plugin` under the fork's package.
- **Build** p620 and razer with `nixos-rebuild build`. In each system
  closure (`nix-store -qR`):
  - exactly one omateams;
  - it is the fork's package;
  - its `.omateams-wrapped` links only `qtwebengine-6.140.0` (check with
    `ldd`);
  - omaoutlook's Main.qml contains that same `/bin/omateams` path;
  - no `qtwebengine-6.140.0-rc` reaches omateams.
- **Gone:** `grep -rn "customPkgs.omateams\|pkgs/omateams" .` finds nothing.
- **Runtime on p620,** after `nixos-rebuild switch`, which needs the owner's
  OK:
  - Teams is still signed in;
  - the bar widget shows and the host started hidden;
  - `omateams status` shows `version: 1.4.1` and `captured: false`;
  - share and stop 3 times: no `eglCreateSync failed` in
    `journalctl --user`, and `hostMemory` stays near its start;
  - a Teams link opened from omaoutlook opens in omateams.
- **Runtime on razer:** it starts, is signed in, and shows the bar widget.

## Open questions

None. The intent's two questions were settled at approval.
