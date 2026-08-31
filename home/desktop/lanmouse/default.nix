{ pkgs, inputs, ... }: {
  # add the home manager module
  imports = [ inputs.lan-mouse.homeManagerModules.default ];

  programs.lan-mouse = {
    enable = true;
    # The flake input's own package builds every crate from source through the
    # legacy cargo-vendor-dir fetcher, which pulls each one from
    # crates.io/api/v1/<crate>/<version>/download. That endpoint now answers 403
    # to Nix's fetcher user-agent (a browser UA and static.crates.io both still
    # return 200), so the build cannot get its dependencies at all.
    #
    # nixpkgs ships the same 0.11.0 prebuilt on cache.nixos.org, so take the
    # binary and keep the flake input only for the Home Manager module above.
    package = pkgs.lan-mouse;
    # systemd = false;
    # Optional configuration in nix syntax, see config.toml for available options
  };
}
