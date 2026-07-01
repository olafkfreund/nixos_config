{ inputs }:
[
  (final: _prev: {
    customPkgs = import ../pkgs { pkgs = final; };
  })

  (_final: prev: {
    zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  (_final: prev: {
    gogmail = inputs.gogmail.packages.${prev.stdenv.hostPlatform.system}.gogmail;
  })

  # Claude Desktop — Anthropic's OFFICIAL Linux beta, packaged from the signed
  # apt-repo .deb (pkgs/claude-desktop-beta). Replaced the aaddrick Windows-
  # repackage in #986. Attribute name kept as `claude-desktop-linux` so
  # downstream refs (pkgs/default.nix, modules/ai) are unchanged.
  # Bump: see the header comment in pkgs/claude-desktop-beta/default.nix.
  (final: _prev: {
    claude-desktop-linux = final.callPackage ../pkgs/claude-desktop-beta { };
  })

  (_final: prev: {
    cosmic-applet-spotify = inputs.cosmic-applet-spotify.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  # Rust toolchain overlay — exposes `rust-bin.*` on `final` so packages
  # that need a newer rustc than nixpkgs ships (e.g. splashboard) can
  # build with `makeRustPlatform`. Doesn't replace the default `rustc`.
  inputs.rust-overlay.overlays.default

  (import ./custom-packages.nix)
  (import ./citrix-workspace.nix)
  (import ./cmake-compat.nix)
  (import ./python-compat.nix)
  (import ./upstream-fixes.nix)
]
