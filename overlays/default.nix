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

  # Claude Desktop (FHS variant from aaddrick/claude-desktop-debian).
  # See /update-claude-code for the bump workflow.
  (_final: prev: {
    claude-desktop-linux = inputs.claude-desktop-linux.packages.${prev.stdenv.hostPlatform.system}.claude-desktop-fhs;
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
