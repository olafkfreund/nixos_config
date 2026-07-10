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
    };
  };
}
