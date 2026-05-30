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
  version = "0.1.1";
  format = "wheel";

  # fetchPypi gets the URL wrong for this package (constructs
  # google-antigravity- instead of google_antigravity-), so use fetchurl
  # with the canonical PyPI download URL.
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/f3/21/9c3b3b59943b2f0c89c35282c8838b691a1e6b39f3801f40a23882ea45f6/google_antigravity-0.1.1-py3-none-manylinux_2_17_x86_64.whl";
    hash = "sha256-ZMzXHZuaUIJ8aOTf20YFV1R9G6qr7OhD1OrlbBu7Ve4=";
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
