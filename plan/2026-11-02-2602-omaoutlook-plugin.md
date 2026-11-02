---
status: draft
issue: 2602
spec: spec/2026-11-02-2602-omaoutlook-plugin.md
---

<!-- markdownlint-disable MD013 -->

# Plan: Microsoft Outlook as an Omarchy plugin on p620 and razer

## Decisions carried from the approved spec

- Package omaoutlook 1.0.7 at `ad934b6fabe3a34e33e72108e809a3612836101c`,
  hash `sha256-IhJs2Cn1hqc8Tq+Y/eKq7iMn4FRT8648w06VePhhCAg=` (prefetched
  2026-11-02), as `pkgs/omaoutlook`. It is a copy of `pkgs/omateams/default.nix`
  with the names swapped.
- Patches, all `--replace-fail`:
  - `ui/Service.qml`: `hostBinary` points at the store binary, and both
    `ensureHost()` calls become `checkInstalled()`.
  - `host/qml/Main.qml`: `teamsBinary` points at `${omateams}/bin/omateams`.
- Not shipped: `install.sh`, `uninstall.sh`, `assets/omaoutlook-mailto.desktop`.
  HEY keeps `mailto:`.
- The host app's PATH gets `hyprland libnotify coreutils bash xdg-utils`.
- Upstream defaults: the M365 URL, the bar icon with its count, and starting
  hidden with the shell.
- Host module `hosts/common/nixos/omarchy-omaoutlook.nix`, a mirror of
  `omarchy-omateams.nix`, which passes the same overridden `omateams`. It is
  imported on p620 and razer after `omarchy-omateams.nix`.
- A new row in `check-updates.md`.

## Steps

1. **`pkgs/omaoutlook/default.nix`** (new). Copy `pkgs/omateams/default.nix`
   and change:
   - add the args `omateams` and `xdg-utils`;
   - the header comment says `Omaoutlook (Divanyx/omaoutlook): Microsoft
     Outlook web …` and keeps its `# Bump against: gh api
     repos/Divanyx/omaoutlook/commits --jq '.[0].sha'` line;
   - `pname = "omaoutlook"; version = "1.0.7";` with the src rev and hash
     above;
   - `qmakeFlags = [ "OMAOUTLOOK_VERSION=${version}" ];`;
   - `postPatch` uses the three Service.qml replacements with
     `omateams`→`omaoutlook` in `hostBinary`'s path, plus
     `substituteInPlace host/qml/Main.qml --replace-fail 'readonly property string teamsBinary: Sys.home() + "/.local/share/omateams/bin/omateams"' 'readonly property string teamsBinary: "${omateams}/bin/omateams"'`.
     Because `Main.qml` is compiled in through `qml.qrc`, add `grep -qF
     "${omateams}/bin/omateams" host/qml/Main.qml` at the end of
     `postPatch`;
   - `installPhase` installs `bin/omaoutlook`, `assets/omaoutlook.desktop`,
     `assets/omaoutlook.svg`, and copies `manifest.json ui preview.png
     LICENSE` into `share/omaoutlook/plugin/`;
   - `qtWrapperArgs` PATH: `[ hyprland libnotify coreutils bash xdg-utils ]`;
   - `installCheckPhase` has the same four checks as omateams, renamed;
   - `meta` with `description = "Microsoft Outlook web client as an Omarchy
     shell plugin"`, `homepage`, `mit`, and `mainProgram = "omaoutlook"`.

   Check: `nix build --impure --expr 'let p = (builtins.getFlake (toString ./.)).nixosConfigurations.p620.pkgs; in p.callPackage ./pkgs/omaoutlook { omateams = p.customPkgs.omateams; }'`.
   Traps: `--replace-fail` must match upstream byte for byte (copy the lines
   from the source at that rev). There is no overlay, only `callPackage`
   ([[overlay-cache-poisoning]]).

2. **`pkgs/default.nix:55`**: after `omateams`, add
   `# Omaoutlook: Microsoft Outlook web in an Omarchy-themed window (#2602).`
   and `omaoutlook = pkgs.callPackage ./omaoutlook { omateams = pkgs.callPackage ./omateams { }; };`.
   The set is not recursive, so `omateams` is passed explicitly. The host
   module overrides it with the hyprland-pinned omateams.
   Check: `nix eval .#nixosConfigurations.p620.pkgs.customPkgs.omaoutlook.name`
   prints `omaoutlook-1.0.7`.

3. **`hosts/common/nixos/omarchy-omaoutlook.nix`** (new): the module from
   the spec, with a header comment in the `omarchy-omateams.nix` style (what
   it is, sign in once per host, the login lives in
   `~/.local/share/omaoutlook`, upgrade by bumping rev and hash, never
   `omarchy plugin update`).
   Check: it is used by step 4.
   Traps: explicit imports only.

4. **`hosts/p620/nixos/nixarchy.nix:41`** and
   **`hosts/razer/nixos/nixarchy.nix:40`**: add
   `../../common/nixos/omarchy-omaoutlook.nix` after `omarchy-omateams.nix`.
   **`.claude/commands/check-updates.md:68`**: add a row after omateams,
   `| pkgs/omaoutlook | \`rev\` in \`pkgs/omaoutlook/default.nix\` | \`gh api repos/Divanyx/omaoutlook/commits --jq '.[0].sha'\` |`.
   Check:`just test-host p620` and `just test-host razer` build.

5. **PR, merge and deploy p620.** The user asked for the p620 deploy on
   2026-11-02. Read the bus, post, then from the shared checkout on `main`
   at the merge commit run `AGENT_BUS_ANNOUNCED=1 just p620`. Check that the
   checkout is on `main` and clean first ([[etc-nixos-is-checkout-branch]]);
   if an `nhs` run holds it, deploy from a detached worktree at
   `origin/main` instead.
   Check: `/run/current-system` equals the `main` build output, no failed
   units, `omaoutlook` is on PATH.
   razer is deployed only when the user asks.

## Tests

```bash
nix eval .#nixosConfigurations.p620.pkgs.customPkgs.omaoutlook.name
just test-host p620
just test-host razer
```

After deploy, on p620: log out and back in (enable-once), then:

```bash
omarchy plugin list | grep omaoutlook
omaoutlook toggle
```

Sign in once. Send yourself a Teams invitation and click Join: it opens in
Omateams. A normal link opens in Chrome.

## Rollback

Remove the two host imports and rebuild. The plugin source disappears with
the generation. `~/.local/share/omaoutlook` holds only the login and can be
deleted by hand.
