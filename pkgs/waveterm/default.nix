# waveterm — custom-tracked latest stable.
#
# Mirrors upstream nixpkgs pkgs/by-name/wa/waveterm/package.nix (Linux only —
# we have no macOS hosts). versions.json is bumped by
# ../../scripts/update-waveterm.sh, which is also wired in as
# passthru.updateScript. Run it before `nhs <host>` whenever you want the
# latest WaveTerm release.
#
# Registered as an overlay in flake.nix so pkgs.waveterm everywhere in
# the repo (notably home/desktop/terminals/wave/default.nix) resolves here.
{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, python3
, atk
, at-spi2-atk
, cups
, libdrm
, gtk3
, pango
, cairo
, libx11
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxrandr
, libgbm
, expat
, libxcb
, alsa-lib
, nss
, nspr
, vips
, udev
, libGL
, libsecret
, makeWrapper
,
}:

let
  pname = "waveterm";
  versions = lib.importJSON ./versions.json;
  arch = if stdenv.hostPlatform.system == "x86_64-linux" then "amd64" else "arm64";
  key = if stdenv.hostPlatform.system == "x86_64-linux" then "linux_x86_64" else "linux_aarch64";
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (versions.${key}) version;

  src = fetchurl {
    inherit (versions.${key}) hash;
    url = "https://github.com/wavetermdev/waveterm/releases/download/v${finalAttrs.version}/waveterm-linux-${arch}-${finalAttrs.version}.deb";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    python3
  ];

  buildInputs = [
    atk
    at-spi2-atk
    cups
    libdrm
    gtk3
    pango
    cairo
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libgbm
    expat
    libxcb
    alsa-lib
    nss
    nspr
    vips
    # Electron safeStorage on Linux requires libsecret to back the keyring.
    # Without this, WaveTerm 0.14+ throws "encryption is not available" when
    # saving API keys. GNOME Keyring provides the org.freedesktop.secrets
    # DBus service at runtime; libsecret is the client library Electron links.
    libsecret
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/app
    cp -r opt/Wave $out/app/waveterm
    cp -r usr/share $out/share
    substituteInPlace $out/share/applications/waveterm.desktop \
      --replace-fail "/opt/Wave/" ""
    makeWrapper $out/app/waveterm/waveterm $out/bin/waveterm \
      --prefix LD_LIBRARY_PATH : ${libsecret}/lib

    runHook postInstall
  '';

  preFixup = ''
        patchelf --add-needed libGL.so.1 \
          --add-rpath ${lib.makeLibraryPath [ libGL udev ]} \
          $out/app/waveterm/waveterm

        # Replace WaveTerm brand green (#58c142) with the Alien HUD phosphor
        # accent (#8fd694, base0B of assets/themes/alien-hud.yaml). Hardcoded
        # because a package cannot read config.lib.stylix; if the scheme's
        # base0B changes, change it here too.
        #
        # Every substitution MUST be the same byte length as what it replaces
        # — asar stores a JSON header of absolute offsets, and shifting the
        # payload corrupts the archive. Hence 'rgb(143,214,148)' without
        # spaces: it is exactly as long as 'rgb(88, 193, 66)'.
        # autoPatchelfHook already brings python3 into the build env.
        python3 -c "
    import sys
    path = sys.argv[1]
    data = open(path, 'rb').read()
    for old, new in ((b'#58c142', b'#8fd694'),
                     (b'#58C142', b'#8fd694'),
                     (b'rgb(88, 193, 66)', b'rgb(143,214,148)')):
        assert len(old) == len(new), (old, new)
        data = data.replace(old, new)
    open(path, 'wb').write(data)
    print('waveterm: patched accent green -> alien-hud base0B')
    " "$out/app/waveterm/resources/app.asar"
  '';

  passthru.updateScript = ../../scripts/update-waveterm.sh;

  meta = {
    description = "Open-source, cross-platform terminal for seamless workflows (custom-tracked latest stable)";
    homepage = "https://www.waveterm.dev";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "waveterm";
  };
})
