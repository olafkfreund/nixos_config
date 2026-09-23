---
status: draft
issue: 1978
spec: spec/2026-09-23-1978-streamdeck-session-units.md
---

# Plan: Stream Deck daemons follow the graphical session

## Approved decisions (self-contained)

- **Package omgato in Nix**, pinned to the release the plugin runs: v0.1.7
  from `github:data-goblin/omgato`. One cargo workspace with four binaries
  (`streamdeck-ctl`, `camlink-ctl`, `keylight-ctl`, `omgato-panel`), all
  installed, because the bar widget calls each one by bare name on `PATH`.
  Build deps are `pkg-config` plus `systemdLibs` (hidapi's libudev). Add
  `libusb1` only if the build fails without it. There are no git
  dependencies, so there are no `outputHashes`.
- **User units in Home Manager, p620 only**, keeping upstream's names
  `streamdeck-ctl-deck.service` (`deck run`) and `streamdeck-ctl.service`
  (`pedal run`), because the widget starts and stops them by name. Both get
  `PartOf` + `After` + `WantedBy` `graphical-session.target`, with
  `Restart=on-failure`, `RestartSec=2` and `StartLimitIntervalSec=60`/`Burst=20`,
  plus `ExecStart` from the store path. No `Environment=`: uwsm imports the
  session env at login.
- **udev**: ship upstream's `70-streamdeck-ctl.rules` in the package and add
  it via `services.udev.packages` on p620.
- **One-time manual cleanup** of the hand install before the first deploy.
  The plugin clone stays, because `omarchy plugin` owns it.
- **Report upstream** to data-goblin/omgato once proven.
- Rejected: units only with the hand-built binary, `default.target` with an
  env wait, and a NixOS-level user unit.

## Steps

1. `pkgs/omgato/default.nix` (new): `rustPlatform.buildRustPackage` with
   `pname = "omgato"`, `version = "0.1.7"`,
   `src = fetchFromGitHub { owner = "data-goblin"; repo = "omgato"; tag = "v${version}"; hash = …; }`,
   `cargoHash`, `nativeBuildInputs = [ pkg-config ]`, `buildInputs = [ systemdLibs ]`,
   and `postInstall` with `install -Dm0644 src/streamdeck-ctl/udev/70-streamdeck-ctl.rules -t $out/lib/udev/rules.d`.
   Add a header comment with two points: bump this together with the Omarchy
   plugin (`manifest.json` version), and don't run upstream's `scripts/install`,
   because Home Manager owns the units. `meta.license = licenses.mit`,
   `platforms = linux`.
   → verify by getting the hashes from `lib.fakeHash` build errors.
2. `pkgs/default.nix`: add `omgato = pkgs.callPackage ./omgato { };` after
   `glab-tui`.
   → verify with `nix build .#nixosConfigurations.p620.pkgs.customPkgs.omgato`:
   `ls result/bin` shows the four binaries and `result/lib/udev/rules.d/`
   has the rule.
3. `Users/olafkfreund/p620_home.nix`: add `pkgs.customPkgs.omgato` to
   `home.packages`, and add `systemd.user.services.streamdeck-ctl-deck` and
   `.streamdeck-ctl` as decided above, using a small `let` helper
   `mkDeckUnit = desc: args: { … }` so the two stay identical except
   Description/ExecStart.
   → verify with `nix eval` of
   `.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.systemd.user.services.streamdeck-ctl-deck.Install.WantedBy`
   = `[ "graphical-session.target" ]`.
4. `hosts/p620/configuration.nix`: `services.udev.packages = [ pkgs.customPkgs.omgato ];`
   → verify that `nix eval` of `config.services.udev.packages` contains omgato.
5. `just check-syntax` and `just test-host p620` → both exit 0.
6. Open the PR (links intent, spec and plan). Merge after review.
7. **Manual cleanup on p620, right before the deploy** (the user runs it, or
   the agent runs it with approval):

   ```sh
   systemctl --user disable --now streamdeck-ctl-deck streamdeck-ctl
   rm ~/.config/systemd/user/streamdeck-ctl-deck.service ~/.config/systemd/user/streamdeck-ctl.service
   rm ~/.local/bin/streamdeck-ctl ~/.local/bin/camlink-ctl ~/.local/bin/keylight-ctl ~/.local/bin/omgato-panel
   systemctl --user daemon-reload
   ```

   → verify that `ls ~/.config/systemd/user/ | grep streamdeck` is empty and the
   `default.target.wants` links are gone.
8. Announce on the agent bus, then deploy p620 (`just quick-deploy p620`).
   → verify with Tests 1–3 below.
9. The user logs out and back in → Test 4.
10. Open the upstream issue on data-goblin/omgato. Write the body to a file and
    pass it with `--body-file`.

## Tests

1. `systemctl --user show -p PartOf,WantedBy,FragmentPath streamdeck-ctl-deck`
   → `graphical-session.target` in both, and FragmentPath is under
   `~/.config/systemd/user` pointing to `/nix/store`. Same for `streamdeck-ctl`.
2. `command -v streamdeck-ctl` → `/etc/profiles/per-user/olafkfreund/bin/…`
   or `~/.nix-profile/bin/…`, not `~/.local/bin`.
3. `systemctl --user is-active streamdeck-ctl-deck` → `active`, and the deck
   shows its page.
4. After re-login: `ActiveEnterTimestamp` of both units is later than the
   new `graphical-session.target` `ActiveEnterTimestamp`.
   `tr '\0' '\n' < /proc/$(systemctl --user show -p MainPID --value streamdeck-ctl-deck)/environ | grep HYPRLAND_INSTANCE_SIGNATURE`
   matches `hyprctl instances`. A deck button opens its menu on screen.
5. The Omgato bar widget's deck toggle stops and starts the daemon.

## Rollback

- Code: revert the PR and deploy p620.
- Get the old behaviour back by hand. This rebuilds and relinks the binaries
  and reinstalls the old units:

  ```sh
  cd ~/.config/omarchy/plugins/io.github.data-goblin.omgato
  nix-shell -p pkg-config systemdLibs libusb1 cargo \
    --run 'scripts/install --no-preset --no-skill'
  systemctl --user enable --now streamdeck-ctl-deck streamdeck-ctl
  ```
