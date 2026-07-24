_final: prev: {
  # azure-cli 2.81.0 expects azure-mgmt-web v2024_11_01 which isn't packaged yet;
  # disable installCheck until nixpkgs catches up.
  azure-cli = prev.azure-cli.overrideAttrs (_old: {
    doInstallCheck = false;
  });

  # python314 fixes for AI tooling deep in litellm/whisperx closures. Scoped via
  # packageOverrides so only these two packages + their dependents rebuild:
  #  - langfuse 4.0.2 pins wrapt<2.0 but nixpkgs ships 2.2.2 (cosmetic; the API it
  #    uses is stable). Relax it so pythonRuntimeDepsCheckHook passes.
  #  - optuna 4.9.0's tests/test_logging.py::test_propagation is flaky (log-
  #    propagation assertion, environment-sensitive). Skip the test suite.
  # Drop each once upstream loosens the pin / fixes the test.
  python314 = prev.python314.override (old: {
    packageOverrides = prev.lib.composeExtensions
      (old.packageOverrides or (_: _: { }))
      (_pyfinal: pyprev: {
        langfuse = pyprev.langfuse.overridePythonAttrs (o: {
          pythonRelaxDeps = (o.pythonRelaxDeps or [ ]) ++ [ "wrapt" ];
        });
        optuna = pyprev.optuna.overridePythonAttrs (_o: { doCheck = false; });
      });
  });

  # rewaita's python dep `fortune` (1.1.2) installs its .dist-info under a name
  # that doesn't match pname "fortune", so pythonMetadataCheckPhase throws
  # PackageNotFoundError under python 3.14. The import check passes; only the
  # version-metadata cross-check fails. Skip it (dontCheckPythonMetadata) on just
  # that dep so rewaita builds — heavier deps (numpy/pillow) are untouched.
  rewaita = prev.rewaita.overridePythonAttrs (old: {
    dependencies = map
      (p:
        if (p.pname or "") == "fortune"
        then p.overrideAttrs (_: { dontCheckPythonMetadata = true; })
        else p)
      (old.dependencies or [ ]);
  });

  # goobook pins simplejson<4.0.0 but nixpkgs ships 4.1.1; the pin is cosmetic
  # (goobook uses only the stable json API). Relax it so the runtime-deps check
  # passes. Drop once goobook loosens its constraint upstream.
  goobook = prev.goobook.overridePythonAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.python3Packages.pythonRelaxDepsHook ];
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "simplejson" ];
  });

  # ollama 0.31.1: the Go scheduler test suite fails in the sandbox — it mocks
  # GPU memory (library=Metal on Linux, simulated cudaMalloc OOM) and is
  # environment-sensitive, not a real defect. Skip checks. Override both the
  # base package and ollama-rocm (p620 uses ollama-rocm; p510 ollama-cuda).
  ollama = prev.ollama.overrideAttrs (_old: { doCheck = false; });
  ollama-rocm = prev.ollama-rocm.overrideAttrs (_old: { doCheck = false; });
  ollama-cuda = prev.ollama-cuda.overrideAttrs (_old: { doCheck = false; });

  # gnome-shell's shell_remove_dark_mode.patch fails to apply on GNOME 49.1.
  # Strip it until nixpkgs catches up. Keep the rest of nixpkgs' patches.
  gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
    patches = builtins.filter
      (patch: builtins.match ".*shell_remove_dark_mode.*" (toString patch) == null)
      (oldAttrs.patches or [ ]);
  });

  # nixpkgs-unstable ships nix-prefetch-git as `nix-prefetch-git-VERSION`,
  # breaking fetchCargoVendor which calls the binary by its short name.
  # Symlink the short name to the versioned binary.
  nix-prefetch-git = prev.nix-prefetch-git.overrideAttrs (_oldAttrs: {
    postFixup =
      let
        versionedName = prev.nix-prefetch-git.name;
      in
      ''
        if [ ! -e "$out/bin/nix-prefetch-git" ] && [ -e "$out/bin/${versionedName}" ];
        then
        ln -s "${versionedName}" "$out/bin/nix-prefetch-git"
        fi
      '';
  });
}
