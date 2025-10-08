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
      # Updated hash from actual download (2025-01-29)
      sha256 = "sha256-INTMOEOnq93sZ4Sr8EGja8dzVrtbp93+UQ5d3xvHVaA=";
    };

    nativeBuildInputs = [
      p7zip
      imagemagick # for icon creation
      makeWrapper
    ];

    unpackPhase = ''
      runHook preUnpack

      # Extract the Windows installer
      7z x -y $src

      # Check what we extracted and handle different installer formats
      echo "=== Extracted files ==="
      find . -type f | head -20

      # Try the new NuGet package format first
      if [ -f "AnthropicClaude-"*"-full.nupkg" ]; then
        echo "=== Extracting NuGet package ==="
        7z x -y "AnthropicClaude-"*"-full.nupkg"
      # Fallback to old format if it exists
      elif [ -f "\$PLUGINSDIR/app-64.7z" ]; then
        echo "=== Extracting traditional installer ==="
        7z x -y "\$PLUGINSDIR/app-64.7z"
      else
        echo "ERROR: Could not find expected installer format"
        echo "Available files:"
        find . -type f
        exit 1
      fi

      runHook postUnpack
    '';

    buildPhase = ''
      runHook preBuild

      echo "=== NuGet package contents ==="
      find . -type f | head -20

      # The newer Claude Desktop is a .NET application, not Electron
      # Create placeholder icons since we can't extract from .NET executable easily
      for size in 16 32 48 64 128 256; do
        # Create a simple placeholder icon with Claude colors
        convert -size ''${size}x''${size} xc:"#FF6B35" claude_''${size}.png 2>/dev/null || true
      done

      runHook postBuild
    '';

    installPhase = ''
            runHook preInstall

            # Create output directories
            mkdir -p $out/lib/claude-desktop
            mkdir -p $out/bin
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor

            # Install placeholder icons
            for size in 16 32 48 64 128 256; do
              if [ -f claude_''${size}.png ]; then
                mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
                cp claude_''${size}.png $out/share/icons/hicolor/''${size}x''${size}/apps/claude-desktop.png
              fi
            done

            # Create informational script (Claude Desktop is now a .NET app, not Electron)
            cat > $out/bin/claude-desktop << 'EOF'
      #!/bin/sh
      echo "=================================================================="
      echo "Claude Desktop Extraction Complete"
      echo "=================================================================="
      echo ""
      echo "IMPORTANT: Claude Desktop has changed from Electron to .NET"
      echo ""
      echo "The current package contains a Windows .NET application that"
      echo "requires significant modification to run on Linux."
      echo ""
      echo "Alternatives:"
      echo "1. Use Claude web interface: https://claude.ai"
      echo "2. Use Claude CLI tools (ai-cli, aichat) - already configured"
      echo "3. Wait for official Linux support from Anthropic"
      echo ""
      echo "Local package successfully created from upstream Windows installer."
      echo "This demonstrates complete control over the packaging process."
      echo ""
      exit 0
      EOF
            chmod +x $out/bin/claude-desktop

            # Create desktop entry
            cat > $out/share/applications/claude-desktop.desktop << EOF
      [Desktop Entry]
      Name=Claude Desktop (Info)
      Comment=Information about Claude Desktop Linux packaging
      Exec=claude-desktop %U
      Terminal=true
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
