{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, makeWrapper
, curl
, icu
, libsecret
, libuuid
, openssl
, sqlite
, webkitgtk_4_1
, xorg
, zlib
, glib
, gtk3
, pam
, dbus
, openjdk11  # CRITICAL: OpenJDK 11 required, NOT default-jre (Java 21)
}:

stdenv.mkDerivation rec {
  pname = "intune-portal";
  version = "1.2511.7";
  buildVersion = "noble";

  src = fetchurl {
    url = "https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/i/intune-portal/intune-portal_${version}-${buildVersion}_amd64.deb";
    hash = "sha256-MHvAmkemx28ZNcVloFNxJ03YbxrgVPvB7OOMYR6Oyo8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    curl
    icu
    libsecret
    libuuid
    openssl
    sqlite
    webkitgtk_4_1
    xorg.libX11
    zlib
    glib
    gtk3
    pam
    dbus
    openjdk11 # CRITICAL: Required for microsoft-identity-broker
  ];

  # Disable automatic ELF patching for PAM module to preserve network functionality
  dontPatchELF = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Create output directories
    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/lib/systemd/user
    mkdir -p $out/lib/security

    # Install main binaries
    cp -r opt/microsoft/intune/bin/* $out/bin/

    # Manually patch the three main executables
    for binary in intune-portal intune-agent intune-daemon; do
      if [ -f "$out/bin/$binary" ]; then
        echo "Patching $binary..."
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
          --set-rpath "${lib.makeLibraryPath buildInputs}" \
          "$out/bin/$binary"
      fi
    done

    # Install PAM module separately (preserve network functionality)
    if [ -f opt/microsoft/intune/pam/pam_intune.so ]; then
      cp opt/microsoft/intune/pam/pam_intune.so $out/lib/security/
      # PAM module needs special library path
      patchelf --set-rpath "${lib.makeLibraryPath [ pam ]}" \
        "$out/lib/security/pam_intune.so"
    fi

    # Install desktop files
    if [ -d opt/microsoft/intune/share/applications ]; then
      cp opt/microsoft/intune/share/applications/*.desktop $out/share/applications/
      # Fix paths in desktop files
      substituteInPlace $out/share/applications/*.desktop \
        --replace /opt/microsoft/intune/bin $out/bin
    fi

    # Install systemd user service files
    if [ -d opt/microsoft/intune/lib/systemd/user ]; then
      cp opt/microsoft/intune/lib/systemd/user/*.service $out/lib/systemd/user/
      # Fix paths in service files
      for service in $out/lib/systemd/user/*.service; do
        substituteInPlace "$service" \
          --replace /opt/microsoft/intune/bin $out/bin
      done
    fi

    # Wrap binaries to ensure Java and other dependencies are in PATH
    for binary in $out/bin/*; do
      if [ -f "$binary" ] && [ -x "$binary" ]; then
        wrapProgram "$binary" \
          --prefix PATH : ${lib.makeBinPath [ openjdk11 curl ]} \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Microsoft Intune Company Portal for Linux";
    longDescription = ''
      Microsoft Intune Company Portal allows you to enroll and manage Linux
      devices in Microsoft Intune. This enables access to corporate resources,
      compliance policies, and conditional access on Linux workstations.

      IMPORTANT: This package requires:
      - OpenJDK 11 (NOT default-jre which installs Java 21)
      - Microsoft Edge browser for authentication
      - GNOME desktop environment (officially supported)
      - Active Microsoft Intune subscription

      Version Control: This is a custom-built package allowing manual version
      control independent of nixpkgs. Update the 'version' and 'hash' attributes
      to upgrade to newer Microsoft releases.

      Upgrade Process:
      1. Find new version at: https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/i/intune-portal/
      2. Update 'version' attribute
      3. Run: nix-prefetch-url https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/i/intune-portal/intune-portal_VERSION-noble_amd64.deb
      4. Update 'hash' attribute with output
      5. Test build: nix build .#intune-portal
      6. Deploy to test host before production
    '';
    homepage = "https://learn.microsoft.com/en-us/intune/intune-service/user-help/microsoft-intune-app-linux";
    changelog = "https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/whats-new";
    license = licenses.unfree;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "intune-portal";
  };
}
