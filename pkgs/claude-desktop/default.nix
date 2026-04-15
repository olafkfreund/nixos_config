{ lib
, stdenvNoCC
, fetchurl
, dpkg
, makeWrapper
, autoPatchelfHook
, buildFHSEnv
, # FHS runtime deps
  docker
, docker-compose
, glibc
, nodejs
, openssl
, uv
  # Electron runtime deps (Chromium stack)
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, gdk-pixbuf
, glib
, gtk3
, libGL
, libdrm
, libnotify
, libpulseaudio
, libsecret
, libuuid
, libxkbcommon
, mesa
, nspr
, nss
, pango
, systemd
, xorg
, wayland
, libxshmfence
, libappindicator-gtk3
}:

let
  pname = "claude-desktop";
  # Pinned to aaddrick release v1.3.30+claude1.2278.0 — the last upstream release
  # that builds cleanly (the patcher for Claude 1.2581.0 bundle is broken upstream).
  # Bump both `version` and `hash` when updating.
  version = "1.2278.0-1.3.30";

  src = fetchurl {
    url = "https://github.com/aaddrick/claude-desktop-debian/releases/download/v1.3.30+claude1.2278.0/claude-desktop_${version}_amd64.deb";
    hash = "sha256-Qxo5A8XRroBtXq4TOXBz1Z+B0gV4Tqi9N0MvZgrM5wk=";
  };

  # Inner: extract the .deb, patch ELF RPATHs, place under Nix-standard prefix.
  # buildFHSEnv will mount $out/bin → /usr/bin and $out/lib → /usr/lib inside the
  # sandbox, which satisfies the launcher's hardcoded /usr/lib/claude-desktop paths.
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version src;

    nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libGL
      libappindicator-gtk3
      libdrm
      libnotify
      libpulseaudio
      libsecret
      libuuid
      libxkbcommon
      libxshmfence
      mesa
      nspr
      nss
      pango
      systemd
      wayland
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
    ];

    dontBuild = true;
    dontConfigure = true;

    # Some shipped binaries (e.g. vendored crashpad helpers) are benign if they
    # can't be patched — don't fail the build on them.
    autoPatchelfIgnoreMissingDeps = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      # Map Debian /usr tree onto the Nix-standard prefix so buildFHSEnv's
      # /usr merging picks it up correctly.
      cp -r usr/bin   $out/bin
      cp -r usr/lib   $out/lib
      cp -r usr/share $out/share

      # Rewrite the desktop-entry Exec to reference the FHS wrapper by name
      # (resolved via PATH inside the sandbox) — the outer buildFHSEnv output
      # is also called `claude-desktop`, so this is stable.
      substituteInPlace $out/share/applications/claude-desktop.desktop \
        --replace-fail "Exec=/usr/bin/claude-desktop" "Exec=claude-desktop"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Claude Desktop for Linux (repackaged from aaddrick/claude-desktop-debian .deb)";
      homepage = "https://github.com/aaddrick/claude-desktop-debian";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = "claude-desktop";
    };
  };
in
buildFHSEnv {
  inherit pname version;

  # FHS runtime: mirrors upstream's claude-desktop-fhs so MCP servers that
  # shell out to `docker` / `node` / `uv` / `openssl` resolve inside the sandbox.
  targetPkgs = _pkgs: [
    unwrapped
    docker
    docker-compose
    glibc
    nodejs
    openssl
    uv
  ];

  runScript = "${unwrapped}/bin/claude-desktop";

  # Copy desktop + icons out of the FHS sandbox so the host menu can launch us.
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons
    cp -r ${unwrapped}/share/applications/. $out/share/applications/
    cp -r ${unwrapped}/share/icons/.        $out/share/icons/
  '';

  meta = unwrapped.meta // {
    description = "Claude Desktop for Linux (FHS-wrapped; MCP-ready)";
  };
}
