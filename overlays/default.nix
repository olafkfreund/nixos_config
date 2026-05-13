{ inputs }:
[
  (final: _prev: {
    customPkgs = import ../pkgs { pkgs = final; };
  })

  (_final: prev: {
    zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  # Claude Desktop (FHS variant from aaddrick/claude-desktop-debian).
  # See /update-claude-code for the bump workflow.
  (_final: prev: {
    claude-desktop-linux = inputs.claude-desktop-linux.packages.${prev.stdenv.hostPlatform.system}.claude-desktop-fhs;
  })

  (_final: prev: {
    cosmic-ext-applet-music-player = inputs.cosmic-music-player.packages.${prev.stdenv.hostPlatform.system}.default;
    cosmic-applet-spotify = inputs.cosmic-applet-spotify.packages.${prev.stdenv.hostPlatform.system}.default;
    inherit (inputs.cosmic-ext-radio-applet.packages.${prev.stdenv.hostPlatform.system}) cosmic-ext-applet-radio;
    cosmic-ext-web-apps = inputs.cosmic-ext-web-apps.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  inputs.cosmic-ext-connect.overlays.default

  # Rust toolchain overlay — exposes `rust-bin.*` on `final` so packages
  # that need a newer rustc than nixpkgs ships (e.g. splashboard) can
  # build with `makeRustPlatform`. Doesn't replace the default `rustc`.
  inputs.rust-overlay.overlays.default

  # Replace nixpkgs `pkgs.openclaw` (marked insecure due to default unsandboxed
  # tool access) with the upstream flake's repackaged build. The HM module
  # defaults `programs.openclaw.package` to `pkgs.openclaw`, so the overlay is
  # how the flake author intends consumers to wire it up.
  inputs.nix-openclaw.overlays.default

  (import ./custom-packages.nix)
  (import ./citrix-workspace.nix)
  (import ./cmake-compat.nix)
  (import ./python-compat.nix)
  (import ./upstream-fixes.nix)
]
