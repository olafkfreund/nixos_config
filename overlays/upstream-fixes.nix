_final: prev: {
  # typescript-language-server 6.0.2's pnpm-deps hash is wrong in nixos-unstable
  # 7fd4004; fixed on master by nixpkgs#572951. Drop once unstable has it.
  typescript-language-server = prev.typescript-language-server.overrideAttrs (old: {
    pnpmDeps = old.pnpmDeps.overrideAttrs {
      outputHash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
    };
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

  # playerctl 2.4.1's playerctld segfaults on a D-Bus error reply with no body
  # (e.g. from cliamp) and on NULL cached player properties (#1987). Upstream
  # daemon code is unchanged since 2021; kept local by decision.
  # Drop or rebase when nixpkgs bumps playerctl past 2.4.1.
  playerctl = prev.playerctl.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./playerctl-null-variant.patch ];
  });

  # azure-cli 2.81.0 expects azure-mgmt-web v2024_11_01 which isn't packaged yet;
  # disable installCheck until nixpkgs catches up.
  azure-cli = prev.azure-cli.overrideAttrs (_old: {
    doInstallCheck = false;
  });

  # invoke 3.0.3 (nixpkgs 2cc89a78d) marks fabric 3.2.3 broken, and fabric is an
  # azure-cli dependency. Pinning invoke 2 fails: paramiko 5 pulls invoke 3 into
  # the same closure. azure-cli only does `from fabric import Connection`, and
  # under invoke 3 only the `fab` task runner (Fab_, Executor_) fails its tests;
  # Connection's pass. So relax the pin and skip those two. An extension,
  # not python314.packageOverrides: azure-cli's own python set replaces those.
  # Drop once fabric supports invoke 3.
  # pyopenjtalk-plus: test_run_njd_from_mecab_invalid_input_should_not_break_next_call
  # matches a TypeError message that python 3.14.8 reworded.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyfinal: pyprev: {
      fabric = pyprev.fabric.overridePythonAttrs (o: {
        pythonRelaxDeps = (o.pythonRelaxDeps or [ ]) ++ [ "invoke" ];
        disabledTests = (o.disabledTests or [ ]) ++ [ "Fab_" "Executor_" ];
        meta = o.meta // { broken = false; };
      });
      # sphinx-hook reads "$sphinxBuilders" as a string, so under structuredAttrs
      # only the first builder (html) runs and the "man" output never appears.
      reuse = pyprev.reuse.overridePythonAttrs (o: {
        outputs = prev.lib.remove "man" o.outputs;
        sphinxBuilders = [ "html" ];
      });
      pyopenjtalk-plus = pyprev.pyopenjtalk-plus.overridePythonAttrs (o: {
        disabledTests = (o.disabledTests or [ ]) ++ [
          "test_run_njd_from_mecab_invalid_input_should_not_break_next_call"
        ];
      });
    })
  ];

  # Python builds now default to structuredAttrs (nixpkgs d89172980), so a
  # makeWrapperArgs element is one argv entry and "--prefix PATH : x" reaches
  # makeWrapper whole. Split these two recipes' strings back into words; hplip
  # expands the array unquoted, which now passes only its first element.
  # Drop each once nixpkgs fixes the recipe.
  pywal16 = prev.pywal16.overridePythonAttrs (o: {
    makeWrapperArgs = prev.lib.concatMap (prev.lib.splitString " ") o.makeWrapperArgs;
  });
  better-adb-sync = prev.better-adb-sync.overridePythonAttrs (o: {
    makeWrapperArgs = prev.lib.concatMap (prev.lib.splitString " ") o.makeWrapperArgs;
  });
  hplip = prev.hplip.overrideAttrs (o: {
    preFixup = prev.lib.replaceString ''$makeWrapperArgs "''${gappsWrapperArgs[@]}"''
      ''"''${makeWrapperArgs[@]}" "''${gappsWrapperArgs[@]}"''
      o.preFixup;
  });

  # aggregateModules now cats a .ko.cer for every external module (nixpkgs
  # 6bd752674493); unsigned out-of-tree ones (openrazer, ...) have none and the
  # kernel module tree fails to build. Skip the missing ones, as before that
  # commit. Drop once NixOS/nixpkgs#575192 is fixed.
  aggregateModules = args: (prev.aggregateModules args).overrideAttrs (o: {
    postBuild = prev.lib.replaceString "| xargs -d'\\n' cat >> modules.cer"
      "| while IFS= read -r c; do if [ -e \"$c\" ]; then cat -- \"$c\"; fi; done >> modules.cer"
      o.postBuild;
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
  #  - torchcodec 0.16.0's test_audio_against_cli compares its mp3 output with the
  #    ffmpeg CLI's and fails at 8 kHz against nixpkgs' ffmpeg (blocks whisperx).
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
        torchcodec = pyprev.torchcodec.overridePythonAttrs (o: {
          disabledTests = (o.disabledTests or [ ]) ++ [ "test_audio_against_cli" ];
        });
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
  # qtmultimedia to every Qt program on the host, and a Qt version mismatch
  # there fails the import. The prefix here reaches quickshell alone.
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
    patches = (old.patches or [ ]) ++ [ ./quickshell-desktopentry-parent-watch.patch ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/quickshell \
        --prefix QML_IMPORT_PATH : ${prev.qt6.qtmultimedia}/lib/qt-6/qml \
        --prefix QT_PLUGIN_PATH : ${prev.qt6.qtimageformats}/lib/qt-6/plugins
    '';
  });

}
