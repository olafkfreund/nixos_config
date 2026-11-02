{ lib
, stdenv
, fetchFromGitHub
, qt6
, makeWrapper
, hyprland
, libnotify
, coreutils
, bash
, xdg-utils
, omateams
}:
# Omaoutlook (Divanyx/omaoutlook): Microsoft Outlook web in an Omarchy-themed Qt
# window, plus its shell plugin. Upstream's install.sh compiles the host into
# ~/.local/share at runtime; here the host is built once and Service.qml is
# pointed at the store binary, with the self-install on load turned off.
# Teams links open in omateams, so Main.qml points at the store omateams.
# Bump against: gh api repos/Divanyx/omaoutlook/commits --jq '.[0].sha'
stdenv.mkDerivation rec {
  pname = "omaoutlook";
  version = "1.0.7";

  src = fetchFromGitHub {
    owner = "Divanyx";
    repo = "omaoutlook";
    rev = "ad934b6fabe3a34e33e72108e809a3612836101c";
    hash = "sha256-IhJs2Cn1hqc8Tq+Y/eKq7iMn4FRT8648w06VePhhCAg=";
  };

  nativeBuildInputs = [ qt6.qmake qt6.wrapQtAppsHook makeWrapper ];
  buildInputs = [ qt6.qtbase qt6.qtdeclarative qt6.qtwebengine ];

  preConfigure = "cd host";
  qmakeFlags = [ "OMAOUTLOOK_VERSION=${version}" ];

  # @out@ is unknown here, so it is filled in postInstall.
  postPatch = ''
    substituteInPlace ui/Service.qml \
      --replace-fail 'readonly property string hostBinary: (Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")) + "/omaoutlook/bin/omaoutlook"' 'readonly property string hostBinary: "@out@/bin/omaoutlook"' \
      --replace-fail 'Component.onCompleted: ensureHost()' 'Component.onCompleted: checkInstalled()' \
      --replace-fail 'if (!installed) { ensureHost(); return }' 'if (!installed) { checkInstalled(); return }'
    substituteInPlace host/qml/Main.qml \
      --replace-fail 'readonly property string teamsBinary: Sys.home() + "/.local/share/omateams/bin/omateams"' 'readonly property string teamsBinary: "${omateams}/bin/omateams"'
    # Main.qml is compiled in through qml.qrc, so check the patch landed.
    grep -qF "${omateams}/bin/omateams" host/qml/Main.qml
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 omaoutlook $out/bin/omaoutlook
    cd ..
    install -Dm644 assets/omaoutlook.desktop $out/share/applications/omaoutlook.desktop
    install -Dm644 assets/omaoutlook.svg $out/share/icons/hicolor/scalable/apps/omaoutlook.svg
    mkdir -p $out/share/omaoutlook/plugin
    cp -r manifest.json ui preview.png LICENSE $out/share/omaoutlook/plugin/

    runHook postInstall
  '';

  postInstall = ''
    substituteInPlace $out/share/omaoutlook/plugin/ui/Service.qml --subst-var out
  '';

  qtWrapperArgs = [ "--prefix" "PATH" ":" (lib.makeBinPath [ hyprland libnotify coreutils bash xdg-utils ]) ];

  doInstallCheck = true;
  installCheckPhase = ''
    f=$out/share/omaoutlook/plugin/ui/Service.qml
    grep -qF "$out/bin/omaoutlook" $f
    grep -qF 'Component.onCompleted: checkInstalled()' $f
    test ! -e $out/share/omaoutlook/plugin/install.sh
    # The host restarts itself whenever the running version differs from the manifest's.
    grep -qF '"version": "${version}"' $out/share/omaoutlook/plugin/manifest.json
  '';

  meta = {
    description = "Microsoft Outlook web client as an Omarchy shell plugin";
    homepage = "https://github.com/Divanyx/omaoutlook";
    license = lib.licenses.mit;
    mainProgram = "omaoutlook";
    platforms = lib.platforms.linux;
  };
}
