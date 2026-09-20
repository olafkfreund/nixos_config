_final: prev: {
  # nodejs-slim_26 26.9.0 fails one test in the build sandbox, which takes the
  # whole toplevel with it: podman-desktop -> system-path -> nixos-system.
  #
  #   not ok 1180 parallel/test-fs-cp-async-file-modes
  #   Error: EPERM: operation not permitted, chmod '/build/.../copy_%1/...'
  #
  # A sandbox permissions artifact, not a defect in node: the compile succeeds
  # and only test-ci-js fails. Upstream nixpkgs#564449 has it, Hydra reproduces
  # it (so there is no cached build to fall back on), and nodejs/node#66104 is
  # the fix -- confirmed building clean by two people on that thread.
  #
  # This matters beyond one package: nixos-unstable's head IS the broken
  # revision, so every flake update lands on it and nhs cannot complete (#1891).
  #
  # Costs a local nodejs build, which is why it is scoped to _26 rather than
  # nodejs-slim generally -- our own package sets use the cached nodejs_24, and
  # podman-desktop is the only consumer of _26.
  #
  # Drop once nixpkgs#564449 closes and Hydra has a green nodejs-slim_26.
  nodejs-slim_26 = prev.nodejs-slim_26.overrideAttrs (_old: {
    doCheck = false;
  });

  # gtksourceview5 5.20.0's meson suite hangs in the build sandbox: 9 of 26
  # tests (test-vim-*, test-view, test-buffer, ...) TIMEOUT after 50-90s
  # because there is no locale and no XDG_RUNTIME_DIR. 17 pass, 0 actually
  # fail. Stylix patches a base16 scheme into this package, so it is never in
  # cache.nixos.org and every host rebuilds it locally; p510 is slow enough to
  # hit the timeouts, which takes down pods -> system-path -> the whole
  # toplevel. Skipping the checks costs no cache hits (there were none).
  # Drop once nixpkgs makes those tests sandbox-safe (#1525).
  gtksourceview5 = prev.gtksourceview5.overrideAttrs (_old: {
    doCheck = false;
  });

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
  #  - cheetah3 3.4.0 installs .dist-info as "Cheetah3" not pname "cheetah3", so
  #    pythonMetadataCheckPhase throws PackageNotFoundError (blocks sabnzbd on
  #    p510). Same class as rewaita/fortune — skip the version cross-check.
  # Drop each once upstream loosens the pin / fixes the test / renames dist-info.
  python314 = prev.python314.override (old: {
    packageOverrides = prev.lib.composeExtensions
      (old.packageOverrides or (_: _: { }))
      (_pyfinal: pyprev: {
        langfuse = pyprev.langfuse.overridePythonAttrs (o: {
          pythonRelaxDeps = (o.pythonRelaxDeps or [ ]) ++ [ "wrapt" ];
        });
        optuna = pyprev.optuna.overridePythonAttrs (_o: { doCheck = false; });
        cheetah3 = pyprev.cheetah3.overridePythonAttrs (_o: { dontCheckPythonMetadata = true; });
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

  # quickshell ships no QtMultimedia. Its QML import path is baked at build
  # time and carries qtdeclarative, qtwayland and qtbase plugins only, so any
  # Omarchy shell widget doing `import QtMultimedia` dies at load with
  #
  #   module "QtMultimedia" is not installed
  #
  # taking the whole shell config down, not just that widget. nixpkgs' derivation
  # takes `qt6` as a whole and exposes no feature flag for it.
  #
  # Wrapped rather than set session-wide on purpose: QML_IMPORT_PATH is searched
  # ahead of an application's own path, so exporting it globally would offer this
  # qtmultimedia to every Qt program on the host (kdenlive, obs), and a Qt version
  # mismatch there fails the import. The prefix here reaches quickshell alone.
  #
  # `omarchy-launch-shell` resolves quickshell by name from PATH, so the wrapper
  # is what the session actually runs. Drop if nixpkgs gains a withMultimedia
  # flag or bakes qtmultimedia in.
  #
  # qtimageformats is here for the same reason: qtbase alone decodes PNG/JPEG,
  # so a widget fetching WebP (SpokenShelf asks Audiobookshelf for
  # `cover?format=webp`) logs "Unsupported image format" per image and renders a
  # blank placeholder. Both additions are scoped to this wrapper rather than the
  # session for the reason above.
  quickshell = prev.quickshell.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/quickshell \
        --prefix QML_IMPORT_PATH : ${prev.qt6.qtmultimedia}/lib/qt-6/qml \
        --prefix QT_PLUGIN_PATH : ${prev.qt6.qtimageformats}/lib/qt-6/plugins
    '';
  });

}
