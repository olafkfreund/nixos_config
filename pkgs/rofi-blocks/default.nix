{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  meson,
  ninja,
  rofi,
  json-glib,
  cairo,
  glib,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "rofi-blocks";
  version = "unstable-2025-05-08"; # Using current date for unstable version

  src = fetchFromGitHub {
    owner = "OmarCastro";
    repo = "rofi-blocks";
    # Use latest master commit instead of tagged version
    rev = "d75a9da1516daeef33a13714dfe19d2da9d6c819";
    # Leave hash as empty string initially; Nix will tell us the correct hash
    hash = lib.fakeSha256;
  };

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    makeWrapper
  ];

  buildInputs = [
    rofi
    json-glib
    cairo
    glib # This includes gmodule
  ];

  # Patch the meson.build file to install to our own lib/rofi directory
  # instead of trying to write to the immutable Nix store
  patches = [
    ./meson-install-dir.patch
  ];

  # This ensures the plugin is installed to our package's lib directory
  mesonFlags = [
    "--libdir=${placeholder "out"}/lib"
  ];

  # Create a wrapper script for rofi that includes our plugin directory
  postInstall = ''
    mkdir -p $out/bin
    makeWrapper ${rofi}/bin/rofi $out/bin/rofi-blocks \
      --set ROFI_PLUGIN_PATH $out/lib/rofi
  '';

  meta = with lib; {
    description = "A Rofi modi that allows controlling rofi content through communication with an external program";
    homepage = "https://github.com/OmarCastro/rofi-blocks";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "rofi-blocks";
  };
}
