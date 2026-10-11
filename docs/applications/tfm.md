# tfm (terminal file manager)

Last Updated: 2026-10-11

[tfm](https://github.com/clarkarch/tfm-tui) is a mouse-first terminal file
manager with previews and thumbnails. It is packaged in our own flake,
[nixos-tfm](https://github.com/olafkfreund/nixos-tfm), and installed on
**p620** and **razer** via `features.tfm` in `modules/desktop/tfm.nix`
(Issue #2243).

## Enabling it

```nix
features.tfm = {
  enable = true;
  settings.ui."preview-enabled" = true;
};
```

The feature adds the nixos-tfm Home Manager module to every user through
`home-manager.sharedModules`. The package comes with ffmpeg (for video
thumbnails) and unzip, zip and p7zip on its `PATH`.

## Config

`settings` seeds `~/.config/tfm/config.toml`. Activation writes the file only
when it does not exist, so anything changed in tfm's own Settings screen
survives a rebuild. To reapply the Nix settings, delete the file and rebuild.

## Updating

The nixos-tfm repo checks upstream daily and opens a pull request for a new
release. Once that is merged, pull it in here:

```sh
nix flake update nixos-tfm
```
