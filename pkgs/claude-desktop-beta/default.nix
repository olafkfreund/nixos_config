{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
, # Electron / Chromium runtime
  glib
, gtk3
, nss
, nspr
, atk
, at-spi2-atk
, at-spi2-core
, cairo
, pango
, gdk-pixbuf
, cups
, dbus
, expat
, libdrm
, mesa
, libgbm
, libxkbcommon
, alsa-lib
, libnotify
, libsecret
, libuuid
, systemd
, libseccomp
, libcap_ng
, libpulseaudio
, libGL
, vulkan-loader
, wayland
, xorg
, # Cowork (Local Agent Mode) runtime — spawned as subprocesses at runtime
  qemu_kvm
, virtiofsd
, OVMF
, bubblewrap
,
}:
# Official Claude Desktop for Linux (beta) — Anthropic's own build, packaged
# from the signed apt repo `.deb` (github/app equivalent for Claude). Replaces
# the aaddrick/claude-desktop-debian Windows-repackage we used until #986.
#
# Bump: read the apt Packages index for the latest version + SHA256:
#   curl -fsSL https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
#     | awk '/^Version:/{v=$2} /^Filename:/{f=$2} /^SHA256:/{print v, $2, f}' | sort -V | tail -1
# then update `version` + `sha256` below (hex sha256 from the index is accepted
# by fetchurl as-is).
let
  version = "1.18286.2";

  # dlopen'd at runtime (not in DT_NEEDED) — appended to RUNPATH.
  runtimeLibs = [
    libGL
    vulkan-loader
    libpulseaudio
    libnotify
    libsecret
  ];
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit version;

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
    sha256 = "56fa5de053e0a68dc7583677857bedcf4219b19d90201400e0237b7d74d512f1";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    glib
    gtk3
    nss
    nspr
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    pango
    gdk-pixbuf
    cups
    dbus
    expat
    libdrm
    mesa
    libgbm
    libxkbcommon
    alsa-lib
    libnotify
    libsecret
    libuuid
    systemd
    libseccomp
    libcap_ng
    wayland
  ]
  ++ (with xorg; [
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libXtst
    libXScrnSaver
    libxshmfence
  ])
  ++ runtimeLibs;

  runtimeDependencies = map lib.getLib runtimeLibs;

  unpackCmd = "dpkg-deb -x $curSrc .";
  sourceRoot = ".";

  # Electron apps must not have their asar/native tree stripped or rewritten.
  dontStrip = true;
  dontWrapGApps = true; # we compose the wrapper flags ourselves below

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin $out/share
    cp -r usr/lib/claude-desktop $out/lib/claude-desktop

    # Desktop entry + icons
    cp -r usr/share/applications $out/share/
    cp -r usr/share/icons $out/share/

    # Wrapper: Wayland-aware ozone, GApps/GTK env (gappsWrapperArgs), and PATH
    # for the Cowork helper's subprocesses (qemu/virtiofsd/ovmf/bwrap).
    # --password-store=gnome-libsecret: Electron picks its secret backend from
    # XDG_CURRENT_DESKTOP; under non-GNOME/KDE compositors (niri/labwc/mango)
    # it falls back to the plaintext "basic" store and reports "sign-in won't
    # be saved". Force libsecret so it uses the (unlocked) gnome-keyring.
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "--ozone-platform-hint=auto --password-store=gnome-libsecret" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --prefix PATH : "${lib.makeBinPath [ qemu_kvm virtiofsd bubblewrap ]}" \
      --set-default OVMF_PATH "${OVMF.fd}/FV"

    runHook postInstall
  '';

  meta = {
    description = "Anthropic's official Claude Desktop app for Linux (beta)";
    homepage = "https://claude.ai";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
