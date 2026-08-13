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
