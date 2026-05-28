{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, webkitgtk_4_1
, gtk3
, glib
, cairo
, pango
, gdk-pixbuf
, libsoup_3
, libGL
, libdrm
, mesa
, alsa-lib
}:

stdenv.mkDerivation rec {
  pname = "aerion";
  version = "0.2.5";

  src = fetchurl {
    url = "https://github.com/hkdb/aerion/releases/download/v${version}/aerion-linux-amd64.tar.gz";
    hash = "sha256-rFoZ9gVLfHxJDqoV04NiW5ptpPS9dh+TswoU6b9ZAec=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf
    libsoup_3
    libGL
    libdrm
    mesa
    alsa-lib
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 aerion $out/bin/aerion
    install -Dm644 io.github.hkdb.Aerion.png \
      $out/share/icons/hicolor/256x256/apps/io.github.hkdb.Aerion.png
    install -Dm644 io.github.hkdb.Aerion.desktop \
      $out/share/applications/io.github.hkdb.Aerion.desktop

    substituteInPlace $out/share/applications/io.github.hkdb.Aerion.desktop \
      --replace-quiet "/usr/local/bin/aerion" "$out/bin/aerion" \
      --replace-quiet "/usr/bin/aerion" "$out/bin/aerion" \
      --replace-quiet "Exec=aerion" "Exec=$out/bin/aerion"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/aerion \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
  '';

  meta = {
    description = "Lightweight cross-platform email client (Wails + Svelte)";
    longDescription = ''
      Aerion is an open-source, lightweight email client inspired by Geary.
      Supports IMAP/SMTP, Gmail, Microsoft 365/Outlook, Proton (via Bridge),
      iCloud, Fastmail, and more. Features unified inbox, conversation
      threads, WYSIWYG composer, PGP & S/MIME, and CardDav contact sync.

      This package wraps the upstream prebuilt amd64 Linux binary; OAuth
      client IDs (Gmail/Outlook) are whatever upstream baked in at release.
    '';
    homepage = "https://github.com/hkdb/aerion";
    changelog = "https://github.com/hkdb/aerion/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "aerion";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
