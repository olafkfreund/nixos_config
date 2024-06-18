{ lib
, pkgs
, ...
}:
let
  # pkgs = pkgs.legacyPackages.x86_64-linux;
  buildPythonPackage = pkgs.python311Packages.buildPythonPackage;
  # fetchPypi = pkgs.python311Packages.fetchPypi;

  gkeepapi = buildPythonPackage rec {
    pname = "gkeepapi";
    version = "0.16.0";
    pyproject = true;

    # src = pkgsfetchPypi {
    #   inherit pname version;
    #   hash = "";
    # };

    src = pkgs.fetchFromGitHub {
      owner = "kiwiz";
      repo = "gkeepapi";
      rev = "main";
      sha256 = "sha256-JCFIfhvR4R/YG+w4Me7VYECSnTCfAgcApB+2mub+q68=";
    };

    build-system = [
      pkgs.python311Packages.setuptools
      pkgs.python311Packages.wheel
    ];

    dependencies = [
      pkgs.python311Packages.requests
      pkgs.python311Packages.future
      pkgs.python311Packages.flit-core
      pkgs.python311Packages.gpsoauth
    ];

  };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withPython3 = true;
    withRuby = true;

    extraPython3Packages = p:
      with p; [
        pynvim
        black
        isort
        keyring
        mypy
        pylint
        pynvim
        pytest
        pytest-cov
        types-freezegun
        freezegun
        pip
        virtualenv
        urllib3
        pycryptodomex
        idna
        certifi
        requests
        gpsoauth
        flit-core
        gkeepapi
      ];
  };
}
