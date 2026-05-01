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
}
