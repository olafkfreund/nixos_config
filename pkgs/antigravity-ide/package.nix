{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, glib
, gtk3
, libdrm
, libgbm
, libglvnd
, libnotify
, libsecret
, libuuid
, libxkbcommon
, nspr
, nss
, pango
, systemdLibs
, vulkan-loader
, libx11
, libxscrnsaver
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxtst
, libxcb
, libxshmfence
, libxkbfile
, zlib
,
}:
# Antigravity IDE (formerly "Antigravity Desktop" through 2.0.0).
#
# Major changes from 2.0.0:
#   - Renamed: Antigravity → Antigravity IDE (product rebrand)
#   - CDN: storage.googleapis.com/antigravity-public/antigravity-hub/...
#          → edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/...
#          (back to Google's primary edgedl)
#   - Tarball root: `Antigravity-x64/` → `Antigravity IDE/` (with a space!)
#   - Binary: top-level `antigravity` → `bin/antigravity-ide`
#   - Internal layout: standard Electron `resources/app/` directory tree
#     (no app.asar packaging dance from 2.0.0; node_modules.asar exists
#     but contains no `@vscode/sudo-prompt`, so the 1.x-era pkexec patch
#     stays absent).
#
# Architecture: VS-Code-fork-shaped Electron app with a
# `resources/app/out/` tree of compiled modules + `extensions/antigravity/`
# carrying the Google agent integration.
let
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
    libxkbfile
    zlib
    libglvnd
    vulkan-loader
    systemdLibs
    libnotify
    libsecret
  ];
in
stdenv.mkDerivation {
  pname = "antigravity-ide";
  version = "2.1.1-6123990880747520";

  src = fetchurl {
    url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.1.1-6123990880747520/linux-x64/Antigravity%20IDE.tar.gz";
    hash = "sha256-Wyzr99M6aNAD/Y8fqYjRYAkFrOIlBKCF5ThCFCkIeL0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = runtimeLibs;

  runtimeDependencies = [
    libglvnd
    vulkan-loader
    systemdLibs
    libnotify
    libsecret
  ];

  # Optional bundled-extension deps — ignore if missing.
  autoPatchelfIgnoreMissingDeps = [
    "libwebkit2gtk-4.1.so.0"
    "libsoup-3.0.so.0"
    "libcurl.so.4"
    "libcrypto.so.3"
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/antigravity-ide
    cp -r ./* $out/lib/antigravity-ide/

    # GNOME .desktop launches close stdout on the child Electron process,
    # which trips electron-log's `Error: write EPIPE` on first console
    # write. Redirect when not on a TTY (carried over from 2.0.0 fix).
    mkdir -p $out/bin
    cat > $out/bin/antigravity-ide <<EOF
    #!/usr/bin/env bash
    if [ -t 1 ]; then
      exec "$out/lib/antigravity-ide/bin/antigravity-ide" "\$@"
    else
      exec "$out/lib/antigravity-ide/bin/antigravity-ide" "\$@" >/dev/null 2>&1
    fi
    EOF
    chmod +x $out/bin/antigravity-ide

    # Desktop entry. Icon pulled from the bundled media/ tree.
    mkdir -p $out/share/applications $out/share/pixmaps
    install -Dm644 $out/lib/antigravity-ide/resources/app/out/media/google.svg \
      $out/share/pixmaps/antigravity-ide.svg || true

    cat > $out/share/applications/com.google.antigravity-ide.desktop <<EOF
    [Desktop Entry]
    Name=Antigravity IDE
    Comment=Google's agent-first development IDE
    Exec=$out/bin/antigravity-ide --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto %U
    Icon=antigravity-ide
    Terminal=false
    Type=Application
    Categories=Development;IDE;
    StartupWMClass=Antigravity IDE
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Antigravity IDE — agent-first development environment";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity-ide";
  };
}
