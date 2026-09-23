---
status: draft
issue: 1978
intent: intent/2026-09-23-1978-streamdeck-session-units.md
---

# Spec: Stream Deck daemons follow the graphical session

Decisions from the intent approval: package omgato (open question 1, option
a), pinned to the release the plugin runs (0.1.7), and report the unit binding
upstream once proven here (open question 2).

## Design

### 1. `pkgs/omgato/default.nix`: a Rust package

- `rustPlatform.buildRustPackage` from `fetchFromGitHub { owner = "data-goblin"; repo = "omgato"; tag = "v0.1.7"; }`,
  `cargoHash` (no git dependencies in `Cargo.lock`, so there are no
  `outputHashes`).
- One cargo workspace, four binaries: `streamdeck-ctl`, `camlink-ctl`,
  `keylight-ctl`, `omgato-panel`. Build them all. The Omarchy plugin's bar
  widget (`ui/Panel.qml`) calls every one of them by bare name on `PATH`.
- `nativeBuildInputs = [ pkg-config ]`, `buildInputs = [ systemdLibs ]` for
  `hidapi`'s libudev backend. Add `libusb1` only if the build asks for it (the
  hand build used `nix-shell -p pkg-config systemdLibs libusb1`).
- `postInstall` copies upstream's `src/streamdeck-ctl/udev/70-streamdeck-ctl.rules`
  into `$out/lib/udev/rules.d/`.
- Registered in `pkgs/default.nix` next to `glab-tui`, so it is
  `pkgs.customPkgs.omgato`.

### 2. p620 Home Manager: package and units (`Users/olafkfreund/p620_home.nix`)

- `home.packages = [ pkgs.customPkgs.omgato ]`.
- `systemd.user.services` with the **same unit names** upstream uses, because
  the bar widget starts and stops `streamdeck-ctl-deck.service` and
  `streamdeck-ctl.service` by name (`Panel.qml:85,137`):

  ```nix
  Unit = {
    Description = "Stream Deck (Mk2/XL/Mini) daemon";
    PartOf = [ "graphical-session.target" ];
    After = [ "graphical-session.target" ];
    StartLimitIntervalSec = 60;
    StartLimitBurst = 20;
  };
  Service = {
    ExecStart = "${omgato}/bin/streamdeck-ctl deck run";   # `pedal run` for the other
    Restart = "on-failure";
    RestartSec = 2;
  };
  Install.WantedBy = [ "graphical-session.target" ];
  ```

  `PartOf` stops the units when the session target stops. `WantedBy` starts
  them when it starts. Verified live: under uwsm, `graphical-session.target` is
  `StopWhenUnneeded=yes` and its `ActiveEnterTimestamp` (2026-09-22 23:47:08)
  is the login time, so it really does cycle with each session.

- No `Environment=` or `PATH` in the units. uwsm imports the session
  environment (`WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE`,
  `OMARCHY_PATH`, `PATH`) into the user manager at login. That is why
  today's manual restart fixes the units, and why a unit started at login
  gets the right values.

### 3. udev: `services.udev.packages = [ pkgs.customPkgs.omgato ]` on p620

Deck access works today: `/dev/hidraw1` (vendor `0fd9`) has a `uaccess` ACL
for olafkfreund. But no rule on the system mentions `0fd9`, so the access
comes from a generic rule and could disappear. Shipping upstream's rule makes
it explicit. It is one line, in `hosts/p620/configuration.nix` or a file it
imports.

### 4. One-time cleanup of the hand install (manual, in the plan)

Home Manager cannot take over unit files it does not own. Before the first
deploy:

- `systemctl --user disable --now streamdeck-ctl-deck streamdeck-ctl`
- remove `~/.config/systemd/user/streamdeck-ctl{,-deck}.service`
- remove the four `~/.local/bin/{streamdeck,camlink,keylight}-ctl` and
  `omgato-panel` symlinks into the plugin clone, so they do not shadow the
  packaged binaries on `PATH`

The plugin clone stays: `omarchy plugin` owns it, and it provides the bar
widget. Its `target/` build becomes unused. Nothing runs upstream's
`scripts/install` automatically (the manifest has no install hook), so the
cleanup does not come back by itself.

### 5. Upstream report

After the fix is proven on p620, open an issue on data-goblin/omgato: the
installer's units should be `WantedBy`/`PartOf=graphical-session.target`,
not `default.target`.

## Alternatives rejected

- **Declare only the units and keep `%h/.local/bin/streamdeck-ctl`.** This is
  the smallest diff, but a fresh home or a re-install still needs a hand
  `cargo build` in the plugin clone, which is half the outcome. Rejected at
  the intent gate.
- **Keep `default.target` and add `ExecStartPre` that waits for
  `WAYLAND_DISPLAY`.** That fixes only the first start. A long-running
  daemon would still keep a dead session's environment after the next
  re-login.
- **A NixOS system-level user unit (`systemd.user.services` in NixOS).** It
  works, but the package and the units belong to one user's desktop, and the
  repo keeps user services in Home Manager (`home/shell/gogcli`).

## Risks

- **Package version drift from the plugin.** The widget is updated with
  `omarchy plugin update`, and the binaries are now pinned by Nix. A plugin
  release that adds a CLI subcommand would call a binary that lacks it. The
  mitigation is a comment in `pkgs/omgato` to bump the package together with
  the plugin, whose version is in `manifest.json`.
- **Upstream `scripts/install` run again by hand** would recreate the unit
  files and symlinks and clash with Home Manager. A comment in the package
  says not to run it.
- **Deploy on p620:** HM activation reloads user units. It needs a bus
  announcement. There is no risk to razer or p510.

## Verification

1. `just test-host p620` builds, and `nix build .#nixosConfigurations.p620.pkgs.customPkgs.omgato`
   produces four binaries.
2. After the deploy: `systemctl --user show -p PartOf,WantedBy streamdeck-ctl-deck`
   lists `graphical-session.target`, and the unit file is a store symlink.
3. `which streamdeck-ctl` resolves into the Nix profile, not `~/.local/bin`.
4. **The real test:** log out and back in. Then `systemctl --user show -p ActiveEnterTimestamp streamdeck-ctl-deck`
   is after the new login time, `/proc/<MainPID>/environ` has the current
   `HYPRLAND_INSTANCE_SIGNATURE`, and a deck button opens its menu on screen.
5. The bar widget can still stop and start the deck daemon.
