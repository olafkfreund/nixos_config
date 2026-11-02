---
status: approved
issue: 2602
intent: intent/2026-11-02-2602-omaoutlook-plugin.md
---

<!-- markdownlint-disable MD013 -->

# Spec: Microsoft Outlook as an Omarchy plugin on p620 and razer

## Design

Copy the omateams pattern (#2505) one to one. There is one difference: a
patch that points Teams links at our Omateams.

### Defaults for the intent's open questions

The intent was approved without answers, so these are the defaults. Each one
is easy to change later.

1. **mailto:** HEY keeps `mailto:`. Omaoutlook's `mailtoHandler` stays off
   (upstream default), and `assets/omaoutlook-mailto.desktop` is **not
   installed**, so nothing offers a second handler. Upstream's toggle writes
   `~/.config/mimeapps.list` with `xdg-mime`/`sed`; that file is managed by
   home-manager and is read-only. If you want Outlook for `mailto:` later,
   that is a declarative `xdg.mimeApps` change, not this toggle.
2. **Account:** the upstream default URL, `https://outlook.cloud.microsoft/mail/`
   (Microsoft 365 work or school, so Synechron, like Omateams). It is a
   runtime plugin setting, so no Nix change is needed to switch to
   `outlook.live.com`.
3. **Bar:** the upstream defaults: icon shown, unread count shown, starts
   hidden with the shell.

### 1. Package: `pkgs/omaoutlook/default.nix`

`pkgs/omateams/default.nix` with the names swapped:

- `fetchFromGitHub { owner = "Divanyx"; repo = "omaoutlook"; rev =
  "ad934b6fabe3…"; }` (full sha in the plan), `version = "1.0.7"`, with the
  header comment and the `# Bump against:` line.
- `qt6.qmake` + `wrapQtAppsHook` + `makeWrapper`; `qtbase`, `qtdeclarative`,
  `qtwebengine`. `.pro` is `QT += quick webenginequick network dbus`; `dbus`
  is in qtbase. `preConfigure = "cd host"`, `qmakeFlags = [
  "OMAOUTLOOK_VERSION=${version}" ]`.
- `postPatch`, which fails the build if upstream moves any of these lines:
  - `ui/Service.qml:26`: `hostBinary` → `"@out@/bin/omaoutlook"`.
  - `ui/Service.qml:214` `Component.onCompleted: ensureHost()` and `:129`
    `if (!installed) { ensureHost(); return }` → `checkInstalled()`, exactly
    as omateams.
  - **New:** `host/qml/Main.qml:37` `teamsBinary` → `"${omateams}/bin/omateams"`.
    The package takes `omateams` as an argument, and the host module passes
    the same overridden omateams it installs. Upstream's `Sys.exists()` check
    then finds it, and Teams join links open in Omateams.
- `installPhase`: `bin/omaoutlook`, `assets/omaoutlook.desktop`,
  `assets/omaoutlook.svg`, and the plugin tree (`manifest.json ui
  preview.png LICENSE`) into `share/omaoutlook/plugin`. `install.sh`,
  `uninstall.sh` and `omaoutlook-mailto.desktop` are not shipped.
- `postInstall` `--subst-var out`. `qtWrapperArgs` prefix PATH with
  `hyprland libnotify coreutils bash`, as omateams does. **Add
  `xdg-utils`**, because `Qt.openUrlExternally` routes links to the browser
  through `xdg-open`.
- `installCheckPhase`: the store path is in `Service.qml`, `checkInstalled()`
  is in place, `install.sh` is absent, the manifest version equals `version`,
  and `Main.qml` holds `${omateams}/bin/omateams`. Main.qml is compiled into
  the binary through `qml.qrc`, so this check runs against the patched source
  in `postPatch`.
- Register it in `pkgs/default.nix` after `omateams`, as
  `omaoutlook = pkgs.callPackage ./omaoutlook { };`. The `omateams` argument
  is resolved from `customPkgs`, or passed explicitly; the plan says which.

### 2. Host module: `hosts/common/nixos/omarchy-omaoutlook.nix`

A mirror of `omarchy-omateams.nix`:

```nix
{ config, pkgs, ... }:
let
  omateams = pkgs.customPkgs.omateams.override { hyprland = config.programs.hyprland.package; };
  omaoutlook = pkgs.customPkgs.omaoutlook.override {
    hyprland = config.programs.hyprland.package;
    inherit omateams;
  };
in
{
  imports = [ ./omarchy-enable-once.nix ];
  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins.omaoutlook.src = "${omaoutlook}/share/omaoutlook/plugin";
    home.packages = [ omaoutlook ];
    local.omarchy.enableOnce = [ "omaoutlook" ];
  };
}
```

The overridden `omateams` is the same derivation `omarchy-omateams.nix`
builds, so it adds nothing to the closure.

### 3. Hosts and bookkeeping

- `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`:
  import `../../common/nixos/omarchy-omaoutlook.nix` after
  `omarchy-omateams.nix`.
- `.claude/commands/check-updates.md`: add a row after omateams.

## Alternatives rejected

- **Upstream `install.sh` / `omarchy plugin update`:** it compiles into
  `~/.local/share` at runtime, outside Nix, and breaks on the next GC or Qt
  bump.
- **A Chrome web app for Outlook:** no unread badge, no theme, no Teams
  handoff, which is the reason for asking.
- **Leaving `teamsBinary` unpatched:** every Teams link would open in the
  browser, because the omateams binary is not in `~/.local/share` on Nix.
- **Patching `teamsBinary` to `/etc/profiles/per-user/olafkfreund/bin/omateams`:**
  that hard-codes the user and the home-manager layout. The store path is
  exact and changes with the package.
- **Installing the mailto desktop entry:** it would compete with HEY in the
  MIME cache for a feature that is off.

## Risks

- **Upstream moves a patched line.** `--replace-fail` fails the build
  instead of shipping a plugin that compiles at runtime.
- **Memory.** One more resident WebEngine (upstream's watchdog reloads above
  1.5 GB). razer has less RAM than p620; `runInBackground` can be turned off
  per host at runtime if it matters.
- **Sign-in.** Conditional access on the Synechron tenant could refuse a
  non-Edge client. Omateams was accepted on 2026-10-27 with the same
  WebEngine stack, so this is low risk. If it happens, the build is fine and
  only the login fails; roll back by removing the import.
- **Build cost.** Like omateams, the host compiles in seconds; qtwebengine
  comes from the binary cache.
- Hosts: p620 and razer only.

## Verification

1. `nix build .#nixosConfigurations.p620.pkgs.customPkgs.omaoutlook` (or the
   override through the host) builds, and `installCheckPhase` passes.
2. `just test-host p620` and `just test-host razer` build.
3. After deploying, on p620: one login, then `omarchy plugin list` shows
   omaoutlook enabled, the bar shows the badge, and `omaoutlook toggle`
   opens the themed window. Sign in once.
4. A Teams join link in a test invitation opens in Omateams, not Chrome.
5. A normal link in a message opens in Chrome. `mailto:` still opens HEY.
