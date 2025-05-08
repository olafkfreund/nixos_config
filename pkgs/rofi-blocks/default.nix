{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  meson,
  ninja,
  rofi,
  json-glib,
}:
stdenv.mkDerivation rec {
  pname = "rofi-blocks";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "OmarCastro";
    repo = "rofi-blocks";
    rev = "v${version}";
    hash = "sha256-jO1NeycBo/nl0DVfgXo5P4xU3cwZCX8KMJ1ozuMB4GU=";
  };

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
  ];

  buildInputs = [
    rofi
    json-glib
  ];

  meta = with lib; {
    description = "A Rofi modi that allows controlling rofi content through communication with an external program";
    homepage = "https://github.com/OmarCastro/rofi-blocks";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "rofi-blocks";
  };
}
