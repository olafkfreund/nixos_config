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

  # herdr — TUI agent multiplexer for AI coding agents (see flake input).
  (_final: prev: {
    herdr = inputs.herdr.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  # seance — Zig terminal multiplexer that tracks AI coding agents (flake input).
  (_final: prev: {
    seance = inputs.seance.packages.${prev.stdenv.hostPlatform.system}.default;
  })

  # litellm: add the `expression` module its proxy needs.
  #
  # `litellm --config ...` dies at import with
  #   ModuleNotFoundError: Missing dependency No module named 'expression'.
  #   Run `pip install 'litellm[proxy]'`
  # because nixpkgs' litellm 1.97.0 omits it. dbrattli/Expression is a runtime
  # dependency of the proxy's server code, and nixpkgs has no
  # python3Packages.expression at all, so it is defined here too.
  #
  # The failure is intermittent-looking: systemd restarts the unit, the retry
  # fails the same way, and the service reports active while every request 502s
  # — so a deploy exits 4 without an obviously-dead unit. Not a flake.
  (final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (pyFinal: _pyPrev: {
        expression = pyFinal.buildPythonPackage rec {
          pname = "expression";
          version = "5.7.0";
          pyproject = true;

          src = prev.fetchPypi {
            pname = "expression";
            inherit version;
            hash = "sha256-TF6kJH+HG4ckrVgJEa1zwVUPxlO7Zp2vLUnktkXMR3A=";
          };

          build-system = [ pyFinal.hatchling ];
          dependencies = [ pyFinal.typing-extensions ];

          # The test suite pulls hypothesis + pytest-asyncio for a dependency we
          # only need importable; upstream CI covers it.
          doCheck = false;
          pythonImportsCheck = [ "expression" ];

          meta = {
            description = "Practical functional programming for Python";
            homepage = "https://github.com/dbrattli/Expression";
            license = prev.lib.licenses.mit;
          };
        };
      })
    ];

    litellm = prev.litellm.overridePythonAttrs (old: {
      dependencies = (old.dependencies or [ ]) ++ [ final.python3Packages.expression ];
    });
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
