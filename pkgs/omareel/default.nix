{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, pkg-config
, wayland-scanner
, qt6
, kdePackages
, libevdev
, libjpeg_turbo
, wayland
, wayland-protocols
, ffmpeg
, gpu-screen-recorder
, slurp
}:
let
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "omacom";
    repo = "omareel";
    rev = "v${version}";
    hash = "sha256-mfeyVbFuhJEThzpJ+tOH02SOyg/x630yCLToX5jnQFg=";
  };
in
stdenv.mkDerivation {
  pname = "omareel";
  inherit version src;

  nativeBuildInputs = [ cmake ninja pkg-config wayland-scanner qt6.wrapQtAppsHook qt6.qtshadertools ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtsvg
    kdePackages.layer-shell-qt
    libevdev
    libjpeg_turbo
    wayland
    wayland-protocols
  ];

  cmakeFlags = [ "-DOMAREEL_BUILD_HYPRLAND_PLUGIN=OFF" ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail /usr/share/wayland-protocols ${wayland-protocols}/share/wayland-protocols
    substituteInPlace src/core/OmarchyPaths.cpp \
      --replace-fail /usr/share/omarchy/themes /run/current-system/sw/share/omarchy/themes
  '';

  qtWrapperArgs = [
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [ ffmpeg gpu-screen-recorder slurp ])
  ];

  meta = {
    description = "Screen recorder and editor for Omarchy with synthetic cursor and auto zoom";
    homepage = "https://github.com/omacom/omareel";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "omareel";
  };
}
