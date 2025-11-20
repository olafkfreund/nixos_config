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
, curl
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libdrm
, libglvnd
, libnotify
, libpulseaudio
, libsecret
, libuuid
, libxkbcommon
, libxml2
, mesa
, nspr
, nss
, pango
, systemd
, vulkan-loader
, zlib
, xorg
}:

stdenv.mkDerivation rec {
  pname = "google-antigravity";
  version = "1.11.2";
  buildId = "6251250307170304";

  src = fetchurl {
    url = "http://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}-${buildId}/linux-x64/Antigravity.tar.gz";
    hash = "sha256-1dv4bx598nshjsq0d8nnf8zfn86wsbjf2q56dqvmq9vcwxd13cfi";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    libxml2
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    zlib
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.libxkbfile
    xorg.libxshmfence
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/antigravity $out/share/applications $out/share/pixmaps

    # Copy application files
    cp -r . $out/share/antigravity/

    # Create wrapper script with proper library paths
    makeWrapper $out/share/antigravity/antigravity $out/bin/antigravity \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libglvnd ]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    # Create desktop entry
    cat > $out/share/applications/antigravity.desktop <<EOF
    [Desktop Entry]
    Name=Google Antigravity
    Comment=Agentic Development Platform with Multi-Model AI Support
    Exec=$out/bin/antigravity %U
    Terminal=false
    Type=Application
    Icon=antigravity
    StartupWMClass=Antigravity
    Categories=Development;IDE;
    MimeType=x-scheme-handler/antigravity;
    Keywords=ai;ide;development;gemini;claude;gpt;agentic;
    EOF

    # Extract and install icon (if available)
    if [ -f resources/app/icon.png ]; then
      cp resources/app/icon.png $out/share/pixmaps/antigravity.png
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Antigravity - Agentic Development Platform with Gemini 3, Claude Sonnet 4.5, and GPT-OSS";
    longDescription = ''
      Google Antigravity is an agentic development platform that enables developers
      to operate at a higher, task-oriented level by managing agents across workspaces.

      Features:
      - Multi-model AI support (Gemini 3, Claude Sonnet 4.5, GPT-OSS)
      - Autonomous agent orchestration across editor, terminal, and browser
      - Task-oriented development workflow
      - Dual interface: Editor view and Manager view
      - Free access with generous Gemini 3 Pro rate limits
    '';
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ ];
    mainProgram = "antigravity";
  };
}
