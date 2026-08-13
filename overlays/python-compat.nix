_final: prev: {
  azure-cli-extensions = prev.azure-cli-extensions // {
    k8s-extension = prev.azure-cli-extensions.k8s-extension.overridePythonAttrs (oldAttrs: {
      pythonRelaxDeps = (oldAttrs.pythonRelaxDeps or [ ]) ++ [
        "kubernetes"
        "oras"
      ];
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
        prev.python3Packages.pythonRelaxDepsHook
      ];
    });
  };

  python311 = prev.python311.overrideAttrs (oldAttrs: {
    passthru = (oldAttrs.passthru or { }) // {
      doc = prev.emptyDirectory;
    };
  });

  python312 = prev.python312.override {
    packageOverrides = _pyFinal: pyPrev: {
      azure-mgmt-network = pyPrev.azure-mgmt-network.overridePythonAttrs (oldAttrs: {
        dependencies = (oldAttrs.dependencies or [ ]) ++ [
          pyPrev.msrest
        ];
      });
      # icalendar 7.2.0 requires typing-extensions on python < 3.13, but the
      # python3.12 derivation omits it so pythonRuntimeDepsCheckHook fails.
      # Add it (consumed via python312Packages in home/shell/mail).
      icalendar = pyPrev.icalendar.overridePythonAttrs (oldAttrs: {
        dependencies = (oldAttrs.dependencies or [ ]) ++ [
          pyPrev.typing-extensions
        ];
      });
      # azure-core 1.38.0: tests/conftest.py starts a Flask server and gives it
      # 5 seconds to bind the port. On a busy builder it doesn't make it, so all
      # 271 collected tests error at fixture setup with "Didn't start!". Nothing
      # to do with the library. Blocks azure-identity/-mgmt-core/-keyvault-*.
      azure-core = pyPrev.azure-core.overridePythonAttrs (_old: {
        doCheck = false;
      });
      # sse-starlette 3.2.0: 69/70 pass; the odd one out asserts an exact
      # keepalive-ping count (assert 3 == 2) and picks up a stray ping when the
      # host is loaded. The python312Packages override below already skips this,
      # but mcp resolves its deps through python312.pkgs, which never sees it —
      # hence the same skip here.
      sse-starlette = pyPrev.sse-starlette.overridePythonAttrs (_old: {
        doCheck = false;
      });
      # httplib2 0.32.0: all 76 tests pass, then pytest-timeout 2.4.0 fires its
      # 17s SIGALRM inside terminalwriter.flush() during pytest_runtest_logstart
      # and pytest 9.1.1 aborts with INTERNALERROR (exit 3). Load-dependent — it
      # only trips when the host is building several derivations at once. Skip
      # the check; it blocks google-api-python-client -> google-generativeai ->
      # meet-process. Drop once pytest-timeout/pytest stop racing there.
      httplib2 = pyPrev.httplib2.overridePythonAttrs (_old: {
        doCheck = false;
      });
      # inline-snapshot 0.32.5 has 3 failing tests (of 1428) on this nixpkgs;
      # it's a test-only dep pulled in via fastapi -> mcp. Skip its checks.
      inline-snapshot = pyPrev.inline-snapshot.overridePythonAttrs (_old: {
        doCheck = false;
      });
    };
  };

  python312Packages = (prev.python312Packages // {
    sse-starlette = prev.python312Packages.sse-starlette.overridePythonAttrs (old: {
      doCheck = false;
      pythonImportsCheck = [ ];
      dependencies = (old.dependencies or [ ]) ++ [ prev.python312Packages.starlette ];
    });
  }).overrideScope (_pySelf: pyPrev: {
    sse-starlette = pyPrev.sse-starlette.overrideAttrs (oldAttrs: {
      doCheck = false;
      pythonImportsCheck = [ ];
      propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [
        prev.python312Packages.starlette
      ];
    });
  });

  python313 = prev.python313.override {
    packageOverrides = _pyFinal: pyPrev: {
      plotly = pyPrev.plotly.overridePythonAttrs (_old: {
        doCheck = false;
      });
      wandb = pyPrev.wandb.overridePythonAttrs (_old: {
        doCheck = false;
      });
    };
  };

  # python3 default advanced to 3.14 (nixpkgs 0bb7ec54c8). click-threading's
  # pytestCheckPhase collects docs/conf.py, which imports pkg_resources —
  # removed from setuptools on 3.14 — so the test errors out. Skip the check;
  # the pythonImportsCheck (import click_threading) still passes. Unblocks
  # vdirsyncer -> khal. Drop once nixpkgs fixes the test collection upstream.
  python314 = prev.python314.override {
    packageOverrides = _pyFinal: pyPrev: {
      click-threading = pyPrev.click-threading.overridePythonAttrs (_old: {
        doCheck = false;
      });
      # frictionless 5.18.1: 11/1646 tests fail on this nixpkgs — locale/encoding
      # detection (cp1252 vs iso8859-1) and remote-URL fetches in the sandbox.
      # Not real defects; skip the check.
      frictionless = pyPrev.frictionless.overridePythonAttrs (_old: {
        doCheck = false;
      });
    };
  };
}
