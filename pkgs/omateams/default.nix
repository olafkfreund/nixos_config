{ lib
, stdenv
, fetchFromGitHub
, qt6
, makeWrapper
, hyprland
, libnotify
, coreutils
, bash
, systemd
}:
# Omateams (Divanyx/omateams): Microsoft Teams web in an Omarchy-themed Qt
# window, plus its shell plugin. Upstream's install.sh compiles the host into
# ~/.local/share at runtime; here the host is built once and Service.qml is
# pointed at the store binary, with the self-install on load turned off.
# Bump against: gh api repos/Divanyx/omateams/commits --jq '.[0].sha'
stdenv.mkDerivation rec {
  pname = "omateams";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "Divanyx";
    repo = "omateams";
    rev = "e8264d1cf80204679e1f5da7a13a65342a68837d";
    hash = "sha256-qBL7e/tZeKEG2iZB9WBtTmFbS9+tioMdsO9M8iSXnK0=";
  };

  nativeBuildInputs = [ qt6.qmake qt6.wrapQtAppsHook makeWrapper ];
  buildInputs = [ qt6.qtbase qt6.qtdeclarative qt6.qtwebengine ];

  preConfigure = "cd host";
  qmakeFlags = [ "OMATEAMS_VERSION=${version}" ];

  # @out@ is unknown here, so it is filled in postInstall.
  postPatch = ''
    substituteInPlace ui/Service.qml \
      --replace-fail 'readonly property string hostBinary: (Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")) + "/omateams/bin/omateams"' 'readonly property string hostBinary: "@out@/bin/omateams"' \
      --replace-fail 'Component.onCompleted: ensureHost()' 'Component.onCompleted: checkInstalled()' \
      --replace-fail 'if (!installed) { ensureHost(); return }' 'if (!installed) { checkInstalled(); return }'
    # Everything read off the Color singleton is undefined when a plugin's
    # binding first runs, so neither Color.bar.background nor Color.background
    # can be relied on there: fall back to a literal, or QML warns "Unable to
    # assign [undefined] to QColor". The binding re-runs once Color is ready
    # and the ring gets its real colour (#2778).
    substituteInPlace ui/BarWidget.qml \
      --replace-fail 'border.color: Color.bar.background' 'border.color: (Color.bar && Color.bar.background) || "transparent"'
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 omateams $out/bin/omateams
    cd ..
    install -Dm644 assets/omateams.desktop $out/share/applications/omateams.desktop
    install -Dm644 assets/omateams.svg $out/share/icons/hicolor/scalable/apps/omateams.svg
    mkdir -p $out/share/omateams/plugin
    cp -r manifest.json ui preview.png LICENSE $out/share/omateams/plugin/

    runHook postInstall
  '';

  postInstall = ''
    substituteInPlace $out/share/omateams/plugin/ui/Service.qml --subst-var out
  '';

  qtWrapperArgs = [ "--prefix" "PATH" ":" (lib.makeBinPath [ hyprland libnotify coreutils bash ]) ];

  # QtWebEngine runs the GPU thread inside this process; after a screen share
  # it can leak there without limit (180 GiB on p620, 2026-11-17), and the
  # app's own guard only warns once. A scope with a hard cap lets the kernel
  # end omateams instead of the machine running out of memory.
  postFixup = ''
    mv $out/bin/omateams $out/bin/omateams-unscoped
    cat > $out/bin/omateams <<EOF
    #!${bash}/bin/bash
    if [ -S "\''${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}/bus" ]; then
      exec ${systemd}/bin/systemd-run --user --scope --collect --quiet \\
        -p MemoryHigh=12G -p MemoryMax=16G -p MemorySwapMax=0 \\
        -- $out/bin/omateams-unscoped "\$@"
    fi
    exec $out/bin/omateams-unscoped "\$@"
    EOF
    chmod +x $out/bin/omateams
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    f=$out/share/omateams/plugin/ui/Service.qml
    grep -qF "$out/bin/omateams" $f
    grep -qF 'MemoryMax=16G' $out/bin/omateams
    ${bash}/bin/bash -n $out/bin/omateams
    grep -qF 'Component.onCompleted: checkInstalled()' $f
    test ! -e $out/share/omateams/plugin/install.sh
    # The host restarts itself whenever the running version differs from the manifest's.
    grep -qF '"version": "${version}"' $out/share/omateams/plugin/manifest.json
  '';

  meta = {
    description = "Microsoft Teams web client as an Omarchy shell plugin";
    homepage = "https://github.com/Divanyx/omateams";
    license = lib.licenses.mit;
    mainProgram = "omateams";
    platforms = lib.platforms.linux;
  };
}
