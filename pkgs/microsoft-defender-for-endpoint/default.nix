# Microsoft Defender for Endpoint (MDE) for Linux
# Package implementation using FHSUserEnv for maximum compatibility
#
# References:
# - https://learn.microsoft.com/en-us/defender-endpoint/mde-linux-prerequisites
# - https://learn.microsoft.com/en-us/defender-endpoint/linux-install-manually
# - https://github.com/microsoft/mdatp-xplat

{ lib
, stdenv
, fetchurl
, buildFHSEnv
, dpkg
, makeWrapper
, systemd
, python3
, glibc
, pcre
, libmnl
, libnfnetlink
, libnetfilter_queue
, glib
, openssl
, curl
}:

let
  pname = "mdatp";
  version = "101.25102.0003-insiderfast";

  # Download the latest Debian package from Microsoft repositories
  src = fetchurl {
    url = "https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/m/${pname}/${pname}_${version}_amd64.deb";
    sha256 = "7723720b990d1e890eeba5e2a6beb4c92b04bde011359a96e2537ad85af5c9b2";
  };

  # Extract the Debian package
  extracted = stdenv.mkDerivation {
    name = "${pname}-extracted-${version}";
    inherit src;

    nativeBuildInputs = [ dpkg ];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      mkdir -p $out
      # Copy all extracted contents
      cp -r . $out/
    '';

    meta = {
      description = "Microsoft Defender for Endpoint extracted package";
      platforms = lib.platforms.linux;
    };
  };

in buildFHSEnv {
  name = pname;

  # Define target packages available in the FHS environment
  targetPkgs = pkgs: with pkgs; [
    # System dependencies
    systemd
    python3
    glibc

    # Library dependencies (for versions < 101.25042.0000)
    pcre
    libmnl
    libnfnetlink
    libnetfilter_queue
    glib

    # Network and security
    openssl
    curl

    # Utilities
    coreutils
    util-linux
    procps

    # For onboarding script
    python3Packages.requests
  ];

  # Build the FHS environment structure
  extraBuildCommands = ''
    # Create standard Linux directories expected by MDE
    mkdir -p opt/microsoft/mdatp
    mkdir -p etc/opt/microsoft/mdatp/managed
    mkdir -p var/log/microsoft/mdatp
    mkdir -p lib/systemd/system
    mkdir -p usr/bin

    # Copy extracted MDE files into expected locations
    if [ -d ${extracted}/opt/microsoft/mdatp ]; then
      cp -r ${extracted}/opt/microsoft/mdatp/* opt/microsoft/mdatp/
    fi

    # Copy systemd service file if it exists
    if [ -f ${extracted}/lib/systemd/system/mdatp.service ]; then
      cp ${extracted}/lib/systemd/system/mdatp.service lib/systemd/system/
    elif [ -f ${extracted}/usr/lib/systemd/system/mdatp.service ]; then
      cp ${extracted}/usr/lib/systemd/system/mdatp.service lib/systemd/system/
    fi

    # Create symlink for mdatp client tool
    if [ -f opt/microsoft/mdatp/sbin/wdavdaemonclient ]; then
      ln -s /opt/microsoft/mdatp/sbin/wdavdaemonclient usr/bin/mdatp
    fi
  '';

  # Set up environment variables and PATH
  profile = ''
    export PATH=/opt/microsoft/mdatp/sbin:$PATH
    export MDATP_HOME=/opt/microsoft/mdatp
  '';

  # Run script for entering the FHS environment
  runScript = "bash";

  meta = with lib; {
    description = "Microsoft Defender for Endpoint - Enterprise-grade endpoint detection and response";
    longDescription = ''
      Microsoft Defender for Endpoint (MDE) is a commercial security product that provides:
      - Advanced threat protection
      - Endpoint detection and response (EDR)
      - Integration with Microsoft security ecosystem
      - Real-time malware protection
      - Behavioral analysis and machine learning

      This package uses FHSUserEnv to create a Linux Standard Base environment
      compatible with Microsoft's binary distribution.

      Requirements:
      - Microsoft Defender for Endpoint subscription
      - Onboarding package from Microsoft Defender portal
      - Network access to *.endpoint.security.microsoft.com

      Note: This is a commercial product requiring proper licensing.
    '';
    homepage = "https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-endpoint-linux";
    changelog = "https://learn.microsoft.com/en-us/defender-endpoint/linux-whatsnew";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    maintainers = [ ];  # Add maintainer info
    platforms = platforms.linux;
    mainProgram = "mdatp";

    # Security and usage warnings
    knownVulnerabilities = [
      "Proprietary binary - cannot audit source code"
      "Requires elevated privileges for operation"
      "Network communication with Microsoft endpoints"
    ];
  };
}
