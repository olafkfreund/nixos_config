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
# Antigravity Hub — Google's Antigravity launcher/desktop "hub".
#
# Distinct from antigravity-ide: the IDE rebranded off this CDN at 2.0.0 and
# moved to edgedl, but the `antigravity-hub` product line continues on the
# original GCS bucket and tracks its own version (2.2.x as of writing).
#
#   - CDN:    storage.googleapis.com/antigravity-public/antigravity-hub/...
#   - Tarball root: `Antigravity-x64/`
#   - Binary: top-level `antigravity` (exposed here as `bin/antigravity-hub`)
#
# Version + hash come from the Hy4ri/antigravity-flake version.json tracker,
# same source the `/update-antigravity` command uses. Standard Electron app.
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
  pname = "antigravity-hub";
  version = "2.3.1-5358163105546240";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.3.1-5358163105546240/linux-x64/Antigravity.tar.gz";
    hash = "sha256-ehmSFJ45bswS56QrFVY4lYcB2qplvtB83P5jm4Jnx0U=";
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

  # Optional bundled deps — ignore if absent (mirrors antigravity-ide).
  autoPatchelfIgnoreMissingDeps = [
    "libwebkit2gtk-4.1.so.0"
    "libsoup-3.0.so.0"
    "libcurl.so.4"
    "libcrypto.so.3"
  ];

  dontBuild = true;
  dontConfigure = true;

  # Tarball unpacks to `Antigravity-x64/` (the single source root).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/antigravity-hub
    cp -r ./* $out/lib/antigravity-hub/

    # EPIPE-safe launcher (GNOME .desktop closes the child's stdout, which
    # trips electron-log on first console write — same fix as antigravity-ide).
    mkdir -p $out/bin
    makeWrapper $out/lib/antigravity-hub/antigravity $out/bin/antigravity-hub \
      --add-flags "--password-store=basic"

    mkdir -p $out/share/applications
    cat > $out/share/applications/com.google.antigravity-hub.desktop <<EOF
    [Desktop Entry]
    Name=Antigravity Hub
    Comment=Google Antigravity desktop hub
    Exec=$out/bin/antigravity-hub --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto %U
    Icon=antigravity-hub
    Terminal=false
    Type=Application
    Categories=Development;
    StartupWMClass=Antigravity
    MimeType=x-scheme-handler/antigravity;
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Antigravity Hub — Antigravity desktop launcher";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity-hub";
  };
}
