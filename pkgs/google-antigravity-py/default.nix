{ lib
, buildPythonPackage
, fetchurl
, absl-py
, mcp
, google-genai
, protobuf
, uvicorn
,
}:
# Google Antigravity Python SDK — for building AI agents powered by
# Gemini through the Antigravity infrastructure layer.
#
# The wheel on PyPI is platform-specific and bundles a compiled
# runtime binary, which the upstream README emphasises:
#   "The Google Antigravity SDK relies on a compiled runtime binary
#    that is included in the platform-specific wheels published to
#    PyPI. Cloning this repository alone is not sufficient to run the
#    SDK. Always install from PyPI with `pip install google-antigravity`
#    to obtain the binary."
#
# So we fetch the manylinux x86_64 wheel directly (format = "wheel")
# rather than building from source.
#
# Upstream: https://github.com/google-antigravity/antigravity-sdk-python
buildPythonPackage rec {
  pname = "google-antigravity";
  version = "0.1.24";
  format = "wheel";

  # fetchPypi gets the URL wrong for this package (constructs
  # google-antigravity- instead of google_antigravity-), so use fetchurl
  # with the canonical PyPI download URL.
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/bc/4f/c697485a4fabffd38947eab670485fbcf7e24add178a64c6982f72c4708a/google_antigravity-0.1.24-py3-none-manylinux_2_17_x86_64.musllinux_1_1_x86_64.whl";
    hash = "sha256-Z4xcVqTvqNlLkN+AipOzOc8+rUmLAYmCctWDPIya0T8=";
  };

  propagatedBuildInputs = [
    absl-py
    google-genai
    mcp
    protobuf
    uvicorn
  ];

  # Wheel METADATA declares `uvicorn>=0.46` but our nixpkgs ships 0.40.
  # The package imports fine in practice; skip the strict version check.
  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [ "google.antigravity" ];

  meta = with lib; {
    description = "Google Antigravity Python SDK for building Gemini-powered AI agents";
    homepage = "https://github.com/google-antigravity/antigravity-sdk-python";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
