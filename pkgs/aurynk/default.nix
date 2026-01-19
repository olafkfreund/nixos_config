{ lib
, python3
, fetchFromGitHub
, meson
, ninja
, pkg-config
, wrapGAppsHook4
, desktop-file-utils
, libadwaita
, gtk4
, gobject-introspection
, android-tools
, scrcpy
}:

python3.pkgs.buildPythonApplication rec {
  pname = "aurynk";
  version = "1.2.2";
  format = "other";

  src = fetchFromGitHub {
    owner = "IshuSinghSE";
    repo = "aurynk";
    rev = "v${version}";
    hash = "sha256-jVs7KHSolwKVID5/jm4EfE5Ighr73xExMAjARrQQ8QI=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook4
    gobject-introspection
    desktop-file-utils
  ];

  buildInputs = [
    libadwaita
    gtk4
  ];

  propagatedBuildInputs = with python3.pkgs; [
    pillow
    pygobject3
    pyudev
    qrcode
    zeroconf
  ];

  # Wrapper args to ensure adb and scrcpy are available at runtime
  preFixup = ''
    makeWrapperArgs+=(" --prefix PATH : ${lib.makeBinPath [ android-tools scrcpy ]}")
  '';

  meta = with lib; {
    description = "Android Device Manager for Linux with wireless pairing and device management";
    homepage = "https://github.com/IshuSinghSE/aurynk";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "aurynk";
  };
}
