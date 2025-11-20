{ lib
, buildFHSEnv
, fetchurl
, makeDesktopItem
, stdenv
}:

let
  # Extract the tarball to get the actual antigravity binary
  antigravity-extracted = stdenv.mkDerivation rec {
    pname = "google-antigravity-extracted";
    version = "1.11.2";
    buildId = "6251250307170304";

    src = fetchurl {
      url = "http://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}-${buildId}/linux-x64/Antigravity.tar.gz";
      hash = "sha256-1dv4bx598nshjsq0d8nnf8zfn86wsbjf2q56dqvmq9vcwxd13cfi";
    };

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "antigravity";
    desktopName = "Google Antigravity";
    comment = "Agentic Development Platform with Multi-Model AI Support";
    exec = "antigravity %U";
    icon = "antigravity";
    terminal = false;
    type = "Application";
    categories = [ "Development" "IDE" ];
    mimeTypes = [ "x-scheme-handler/antigravity" ];
    keywords = [ "ai" "ide" "development" "gemini" "claude" "gpt" "agentic" ];
    startupWMClass = "Antigravity";
  };

in
buildFHSEnv {
  name = "antigravity";

  # Complete runtime environment with all necessary libraries
  targetPkgs = pkgs: with pkgs; [
    # Core system libraries
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

    # Graphics and rendering
    libdrm
    libgbm
    libglvnd
    mesa
    vulkan-loader

    # X11 libraries
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

    # System integration
    libsecret
    systemd
    nss
    nspr

    # Audio
    libpulseaudio

    # Additional dependencies for desktop integration
    libappindicator-gtk3
    libdbusmenu
    gsettings-desktop-schemas
    xdg-utils
    libkrb5

    # Utilities
    libnotify
    libuuid
    libxkbcommon
    libxml2
    pango
    zlib
    stdenv.cc.cc.lib
  ];

  # Wrapper script with critical Electron and Antigravity flags
  runScript = ''
    # Set up environment
    export LD_LIBRARY_PATH="${lib.makeLibraryPath [ antigravity-extracted ]}:/run/opengl-driver/lib:$LD_LIBRARY_PATH"

    # Execute antigravity with critical flags
    exec ${antigravity-extracted}/antigravity \
      --no-sandbox \
      --enable-proposed-api google.antigravity \
      ''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}} \
      "$@"
  '';

  # Install desktop entry and icon
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/pixmaps

    # Copy desktop entry
    cp ${desktopItem}/share/applications/*.desktop $out/share/applications/

    # Extract and install icon if available
    if [ -f ${antigravity-extracted}/resources/app/icon.png ]; then
      cp ${antigravity-extracted}/resources/app/icon.png $out/share/pixmaps/antigravity.png
    fi
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

      This package uses buildFHSEnv for maximum Electron compatibility on NixOS.
      Critical flags (--no-sandbox, --enable-proposed-api) are included for proper operation.
    '';
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ ];
    mainProgram = "antigravity";
  };
}
