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
    cosmic-applet-spotify = inputs.cosmic-applet-spotify.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  # ollama 0.30.5 from a pinned master rev — nixos-unstable still on
  # 0.24.0. Only ollama-rocm + ollama-cuda are overridden so the rest of
  # the closure stays on our pinned nixos-unstable. Remove this overlay
  # (and the nixpkgs-ollama flake input) once nixos-unstable advances
  # past 0.30.5. See #784.
  (_final: prev:
    let
      ollamaPkgs = import inputs.nixpkgs-ollama {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    {
      ollama-rocm = ollamaPkgs.ollama-rocm;
      ollama-cuda = ollamaPkgs.ollama-cuda;
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
