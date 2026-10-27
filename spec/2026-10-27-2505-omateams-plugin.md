---
status: approved
issue: 2505
intent: intent/2026-10-27-2505-omateams-plugin.md
---

<!-- markdownlint-disable MD013 -->

# Spec: Microsoft Teams (Synechron) as an Omarchy plugin on p620 and razer

Approved decisions: both hosts; start hidden at login (upstream's
`runInBackground = true` default, so no setting is needed); enable
automatically once at first login.

## What the plugin does at runtime (read from 1.4.1 @ e8264d1)

- `ui/Service.qml:190` runs `ensureHost()` on load, which is
  `bash install.sh --if-needed`. That checks `pacman`, compiles `host/` with
  `qmake6`, and installs to `~/.local/share/omateams/bin/omateams`.
- `ui/Service.qml:26`: `hostBinary` is that `~/.local/share` path. Everything
  else (`maybeAutostart` → `hostBinary --hidden`, `command()`,
  `maybeReplaceHost`, `checkInstalled` → `test -x hostBinary`) goes through it.
- The host app (`host/`, Qt 6 Quick + WebEngineQuick) calls `hyprctl`,
  `notify-send` and `sh` from `PATH`. Its login profile and settings live
  under `QStandardPaths` (`~/.local/share/omateams/`, `~/.config/omateams/`).
  Its status file is `$XDG_RUNTIME_DIR/omateams/status.json`.
- The test build on 2026-10-27 (`stdenv` + `qt6.qmake` + `wrapQtAppsHook`,
  `sourceRoot = "source/host"`) built cleanly against this flake's nixpkgs,
  ran, and Synechron's sign-in accepted it.

## Design

### 1. Package: `pkgs/omateams/default.nix`

One derivation that builds the host app and ships the plugin tree, modelled
on the test build and on `pkgs/omapop`:

- `src = fetchFromGitHub { owner = "Divanyx"; repo = "omateams"; rev = "e8264d1…"; hash = "sha256-qBL7e/tZeKEG2iZB9WBtTmFbS9+tioMdsO9M8iSXnK0="; }`
  (full rev in the plan). `version = "1.4.1"` (matches `manifest.json`).
  Includes `# Bump against: gh api repos/Divanyx/omateams/commits --jq '.[0].sha'`
  and a row in `.claude/commands/check-updates.md`.
- Build: `qt6.qmake`, `qt6.wrapQtAppsHook`, `makeWrapper`; `buildInputs =
  [ qt6.qtbase qt6.qtdeclarative qt6.qtwebengine ]`; run qmake in `host/`
  (`preConfigure = "cd host"`) with `OMATEAMS_VERSION=${version}`, as upstream
  passes it.
- Install:
  - `$out/bin/omateams`, with `qtWrapperArgs += --prefix PATH :
    ${lib.makeBinPath [ hyprland libnotify coreutils bash ]}`. `hyprland` is
    an argument, overridden from the host with
    `config.programs.hyprland.package` (as for omapop), so `hyprctl` matches
    the running compositor.
  - `$out/share/applications/omateams.desktop` and
    `$out/share/icons/hicolor/scalable/apps/omateams.svg`, from `assets/`.
    `Exec=omateams …` resolves through PATH once installed.
  - Plugin tree at `$out/share/omateams/plugin/`: `manifest.json`, `ui/`,
    `preview.png`, `LICENSE`. No `install.sh`/`uninstall.sh`, so there is
    nothing to compile at runtime.
- `substituteInPlace ui/Service.qml` (each `--replace-fail`):
  - The `hostBinary` expression on line 26 becomes the literal
    `"${placeholder "out"}/bin/omateams"`.
  - `Component.onCompleted: ensureHost()` becomes
    `Component.onCompleted: checkInstalled()`. `checkInstalled` then calls
    `maybeAutostart`, which starts it hidden, unchanged.
  - The retry timer (line 277) only calls `ensureHost` in the `needs-deps`
    state, which can't happen any more, so it is left alone.
- `doInstallCheck`: `grep -q '/nix/store/.*/bin/omateams' $out/share/omateams/plugin/ui/Service.qml`,
  and `! grep -q 'install.sh' …/Service.qml || grep -q 'checkInstalled()' …`
  (the build fails if the patch silently missed).

### 2. A shared enable-once hook: `hosts/common/nixos/omarchy-enable-once.nix`

Both this and Altscape (#2503, plan not yet approved) need "enable a plugin
once at first login". Rather than two copies, one small Home Manager module:

- Option `local.omarchy.enableOnce` (list of plugin ids, default `[ ]`),
  merged across modules.
- When it is non-empty, it writes `omarchy/hooks/post-boot.d/enable-once`. The
  hook keeps a marker per id in
  `${XDG_STATE_HOME:-~/.local/state}/nixarchy-local/enabled-once/<id>` and
  exits at once if every id has its marker. Otherwise it waits up to 120 s for
  `omarchy-shell shell ping`, then runs `rescanPlugins` and
  `omarchy-plugin-enable <id>` for each id still missing, writing the marker
  only when that succeeds. Failures go to `systemd-cat -t omarchy-enable-once`.
  `OMARCHY_SHELL_IPC_TIMEOUT=30s`. It never writes `shell.json`. This is
  nixarchy's own `default-plugins` hook in miniature.
- Turning a plugin off in Setup > Plugins sticks, because the marker stays.
- The #2503 plan is revised to use this module instead of its inline hook
  (it is still a draft, so this changes no approved artifact).

### 3. Host module: `hosts/common/nixos/omarchy-omateams.nix`

```nix
{ config, pkgs, ... }:
let
  omateams = pkgs.customPkgs.omateams.override { hyprland = config.programs.hyprland.package; };
in
{
  imports = [ ./omarchy-enable-once.nix ];
  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins.omateams.src = "${omateams}/share/omateams/plugin";
    home.packages = [ omateams ];   # `omateams` on PATH, the desktop entry and the icon
    local.omarchy.enableOnce = [ "omateams" ];
  };
}
```

- `pkgs/default.nix` registers `omateams = pkgs.callPackage ./omateams { };`
  after `omapop`.
- Imported from `hosts/p620/nixos/nixarchy.nix` and
  `hosts/razer/nixos/nixarchy.nix`, after `omarchy-omapop.nix`.
- Where the enable-once module is imported depends on how
  `omarchy-ai-mirror.nix` and the others reach Home Manager options. The plan
  pins this. If the module must be a Home Manager module, it is imported
  through `home-manager.users.olafkfreund.imports`.

## Alternatives rejected

- **Let `install.sh` build it at runtime.** It checks pacman and compiles into
  `~/.local/share` outside Nix: unpinned, and rebuilt whenever Qt changes.
- **Symlink the store binary into `~/.local/share/omateams/bin`.** That leaves
  the Service.qml path unchanged, but it's a mutable link next to your login
  profile and goes stale at the next GC unless managed. Patching the one path
  is cleaner.
- **A Chrome web app on the Synechron profile.** No unread badge and no
  themed window. It stays available as the fallback.
- **Two copies of the enable-once hook (here and in #2503).** Replaced by §2.

## Risks

- **The QtWebEngine version follows nixpkgs.** A Qt bump rebuilds the small
  app (it's cached in nixpkgs, so only our app compiles). If Teams breaks on a
  new Chromium, roll back the generation.
- **Memory:** a hidden Teams window from login, about 1–2 GB on a busy
  tenant. The plugin reloads it above 2 GB (upstream's `memoryLimit`).
  Acceptable: p620 has 251 GiB and razer 62 GiB. The plan measures RSS after a day.
- **Login is per host:** the profile is local, so you sign in once on p620
  and once on razer. It is never synced (it is not in syncthing's paths).
- **Camera:** the Facecam drop-out is hardware (see the intent). A call test
  on p620 depends on the camera being plugged in directly.
- **The enable reload can start a second shell** (memory). The hook runs once
  per id, and the plan restarts the shell cleanly afterwards and checks there
  is a single bar.

## Verification

- `nix build .#nixosConfigurations.p620.pkgs.customPkgs.omateams` builds, and
  installCheck passes.
  `result/bin/omateams --hidden` with throwaway `XDG_*` directories starts,
  and `$XDG_RUNTIME_DIR/omateams/status.json` appears. Quit it with
  `result/bin/omateams quit`.
- `just test-host p620`, `just test-host razer`.
- After deploy, on each host:
  - The enable-once marker exists, and `omarchy plugin list` shows
    `omateams enabled`.
  - The Teams icon is in the bar, and a hidden `omateams` process starts with
    the shell (`pgrep -a omateams` shows the store path).
  - No `~/.local/share/omateams/bin` is created.
  - Exactly one bar.
- You: click the icon, sign in to Synechron once, check the unread badge and a
  notification, then restart the shell or reboot and confirm you are still
  signed in. On p620, a test call with camera and mic.
