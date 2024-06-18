{ lib
, python3Packages
, fetchFromGitHub
, fetchgit
,
}:
python3Packages.buildPythonPackage rec {
  pname = "diffq";
  version = "0.2.4";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "facebookresearch";
    repo = "diffq";
    rev = "refs/tags/v${version}";
    hash = "";
  };

  nativeBuildInputs = with python3Packages; [
    setuptools
    cython
  ];

  propagatedBuildInputs = with python3Packages; [
    numpy
    torch
  ];

  meta = with lib; {
    description = "Description of your package";
    license = licenses.mit;
  };
}
