{ lib
, stdenv
, fetchurl
, makeWrapper
, electron
, p7zip
, asar
, imagemagick
, icoutils
, perl
, buildFHSEnv
, dpkg
}:

let
  pname = "claude-desktop";
  version = "0.13.11";

  # The actual Claude Desktop derivation
  claude-desktop-unwrapped = stdenv.mkDerivation rec {
    inherit pname version;

    # Download the Windows installer (contains the Electron app)
    src = fetchurl {
      url = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe?v=${version}";
      name = "Claude-Setup-x64-${version}.exe";
      # Updated hash from the error message
      sha256 = "sha256-DwCgTSBpK28sRCBUBBatPsaBZQ+yyLrJbAriSkf1f8E=";
    };

    nativeBuildInputs = [
      p7zip
      asar
      makeWrapper
      imagemagick
      icoutils
      perl
    ];

    unpackPhase = ''
      runHook preUnpack

      # Extract the Windows installer with automatic yes to all prompts
      7z x -y $src -o./claude-installer

      # List extracted contents to understand structure
      echo "=== Installer contents ==="
      find ./claude-installer -type f -name "*.7z" -o -name "*.zip" -o -name "*.nupkg" | head -20

      # Extract the app resources - look for different possible locations
      if [ -f ./claude-installer/'$PLUGINSDIR'/app-64.7z ]; then
        7z x -y ./claude-installer/'$PLUGINSDIR'/app-64.7z -o./claude-app
      elif [ -f ./claude-installer/app-64.7z ]; then
        7z x -y ./claude-installer/app-64.7z -o./claude-app
      elif [ -f ./claude-installer/*.nupkg ]; then
        # Extract from NuGet package if that's the format
        7z x -y ./claude-installer/*.nupkg -o./claude-app
      else
        echo "=== All files in installer ==="
        find ./claude-installer -type f | head -20
        echo "ERROR: Could not find app archive"
        exit 1
      fi

      runHook postUnpack
    '';

    buildPhase = ''
      runHook preBuild

      # Extract icons from the Windows executable
      wrestool -x -t 14 ./claude-app/claude.exe > claude.ico 2>/dev/null || true

      # Convert Windows icon to PNG icons for Linux
      if [ -f claude.ico ]; then
        icotool -x claude.ico 2>/dev/null || true

        # Create different sized icons
        for size in 16 32 48 64 128 256 512; do
          if ls claude_*_''${size}x''${size}*.png 1> /dev/null 2>&1; then
            mv claude_*_''${size}x''${size}*.png claude_''${size}.png
          elif ls claude_*.png 1> /dev/null 2>&1; then
            # Create the size if it doesn't exist
            convert claude_*.png -resize ''${size}x''${size} claude_''${size}.png 2>/dev/null || true
          fi
        done
      fi

      # Extract the app.asar to modify it
      cd claude-app/resources
      asar extract app.asar app-unpacked

      # Enable native title bar on Linux (optional modification)
      if [ -f app-unpacked/main.js ]; then
        perl -i -pe 's/frame:\s*false/frame: true/g' app-unpacked/main.js
        perl -i -pe 's/titleBarStyle:\s*"hidden"/titleBarStyle: "default"/g' app-unpacked/main.js
      fi

      # Repackage the modified app
      asar pack app-unpacked app.asar
      rm -rf app-unpacked

      cd ../..

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Create output directories
      mkdir -p $out/lib/claude-desktop
      mkdir -p $out/bin
      mkdir -p $out/share/applications
      mkdir -p $out/share/icons/hicolor

      # Copy the Electron app resources
      cp -r claude-app/resources/* $out/lib/claude-desktop/

      # Install icons
      for size in 16 32 48 64 128 256 512; do
        if [ -f claude_''${size}.png ]; then
          mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
          cp claude_''${size}.png $out/share/icons/hicolor/''${size}x''${size}/apps/claude-desktop.png
        fi
      done

      # Create wrapper script
      makeWrapper ${electron}/bin/electron $out/bin/claude-desktop \
        --add-flags "$out/lib/claude-desktop/app.asar" \
        --set ELECTRON_IS_DEV 0 \
        --set ELECTRON_FORCE_IS_PACKAGED 1 \
        --set NODE_ENV production

      # Create desktop entry
      cat > $out/share/applications/claude-desktop.desktop << EOF
      [Desktop Entry]
      Name=Claude
      Comment=Anthropic's Claude AI Desktop Application
      Exec=claude-desktop %U
      Terminal=false
      Type=Application
      Icon=claude-desktop
      Categories=Office;Chat;
      StartupWMClass=Claude
      MimeType=x-scheme-handler/claude;
      EOF

      runHook postInstall
    '';

    meta = with lib; {
      description = "Claude AI Desktop Application";
      homepage = "https://claude.ai";
      license = licenses.unfree;
      maintainers = [ ];
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  };
in
  # Wrap in FHS environment for better compatibility
  buildFHSEnv {
    name = pname;
    targetPkgs = pkgs: with pkgs; [
      claude-desktop-unwrapped

      # Runtime dependencies
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libGL
      libappindicator-gtk3
      libdrm
      libnotify
      libpulseaudio
      libuuid
      libxkbcommon
      mesa
      nspr
      nss
      pango
      stdenv.cc.cc
      systemd
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
      xorg.libxshmfence

      # Additional dependencies that might be needed
      glibc
      openssl
      nodejs
    ];

    runScript = "claude-desktop";

    extraInstallCommands = ''
      mkdir -p $out/share
      ln -s ${claude-desktop-unwrapped}/share/applications $out/share/applications
      ln -s ${claude-desktop-unwrapped}/share/icons $out/share/icons
    '';

    meta = claude-desktop-unwrapped.meta;
  }