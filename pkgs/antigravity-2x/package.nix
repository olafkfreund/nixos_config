{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  writeShellScript,
  asar,
  bash,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  chromium,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libuuid,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,
  vulkan-loader,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  libxshmfence,
  libxkbfile,
  zlib,
  useFHS ? true,
  useSystemChromeProfile ? true,
  google-chrome ? null,
  extraBwrapArgs ? [],
  srcOverride ? null,
}: let
  pname = "google-antigravity";
  # Antigravity 2.0.0 — Google's 2026-05-19 major release. Vendored locally
  # because upstream jacopone/antigravity-nix is still on 1.23.2 and 2.0
  # changes the CDN path, internal asar layout, launcher location and icon
  # path all at once (see pkgs/antigravity-2x/README.md if you create one,
  # or the PR description). Revert this whole directory once upstream
  # catches up; the only consumer is Users/olafkfreund/profile.nix.
  version = "2.0.0-6324554176528384";

  isAarch64 = stdenv.hostPlatform.system == "aarch64-linux";

  browserPkg =
    if isAarch64
    then chromium
    else if google-chrome != null
    then google-chrome
    else
      throw ''
        google-chrome is required on ${stdenv.hostPlatform.system} builds.
        Make sure you have allowUnfree = true or pass a google-chrome package.
      '';

  browserCommand =
    if isAarch64
    then "chromium"
    else "google-chrome-stable";

  browserProfileDir =
    if isAarch64
    then "$HOME/.config/chromium"
    else "$HOME/.config/google-chrome";

  finalSrc =
    if srcOverride != null
    then srcOverride
    else
      fetchurl {
        # 2.0 ships from a different CDN bucket than 1.x. Old:
        #   edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/...
        url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}/linux-x64/Antigravity.tar.gz";
        hash = "sha256-FLyctIClvo+zt9w+Kwzr+mbTcK1YzB4PoBFA0SBNQpc=";
      };

  # Create a browser wrapper
  # When useSystemChromeProfile is true (default), forces use of the user's
  # existing Chrome profile so extensions are available to Antigravity.
  # When false, omits profile flags so Chrome runs with its own default
  # behavior, isolating Antigravity from the user's main profile.
  chrome-wrapper = writeShellScript "${browserCommand}-with-profile" ''
    set -euo pipefail

    system_browser="/run/current-system/sw/bin/${browserCommand}"
    browser_cmd="$system_browser"

    if [ ! -x "$system_browser" ]; then
      browser_cmd=${browserPkg}/bin/${browserCommand}
    fi

    exec "$browser_cmd" \
      ${lib.optionalString useSystemChromeProfile ''--user-data-dir="${browserProfileDir}" --profile-directory=Default''} \
      "$@"
  '';

  # Libraries loaded via dlopen() at runtime
  dlopenLibs = [
    libglvnd
    vulkan-loader
    systemdLibs
    libnotify
    libsecret
  ];

  # Libraries linked normally (resolved by autoPatchelf via rpath)
  linkedLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
    libxkbfile
    zlib
  ];

  runtimeLibs = linkedLibs ++ dlopenLibs;

  desktopItem = makeDesktopItem {
    name = "antigravity";
    desktopName = "Google Antigravity";
    comment = "Next-generation agentic IDE";
    exec = "antigravity --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3 %U";
    icon = "antigravity";
    categories = ["Development" "IDE"];
    startupNotify = true;
    startupWMClass = "Antigravity";
    mimeTypes = [
      "x-scheme-handler/antigravity"
    ];
  };

  meta = with lib; {
    description = "Google Antigravity - Next-generation agentic IDE";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [];
    mainProgram = "antigravity";
  };

  # ── FHS variant (default) ──────────────────────────────────

  # Extract the upstream tarball without modification
  antigravity-unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = finalSrc;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [asar];

    # 2.0: standard Electron asar layout, no sudo-prompt to patch.

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity
      cp -r ./* $out/lib/antigravity/

      runHook postInstall
    '';

    inherit meta;
  };

  # FHS environment for running Antigravity
  fhs = buildFHSEnv {
    name = "antigravity-fhs";
    targetPkgs = pkgs:
      runtimeLibs
      ++ [
        pkgs.udev
        pkgs.libudev0-shim
      ]
      ++ lib.optional (browserPkg != null) browserPkg;

    extraBwrapArgs = [
      "--bind-try /etc/nixos/ /etc/nixos/"
      "--ro-bind-try /etc/xdg/ /etc/xdg/"
      "--ro-bind-try /etc/nixpkgs/ /etc/nixpkgs/"
    ] ++ extraBwrapArgs;

    runScript = writeShellScript "antigravity-wrapper" ''
      # Set Chrome paths to use our wrapper that forces user profile
      # This ensures extensions installed in user's Chrome profile are available
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}

      exec ${antigravity-unwrapped}/lib/antigravity/antigravity "$@"
    '';

    inherit meta;
  };

  fhs-package = stdenv.mkDerivation {
    inherit pname version meta;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [copyDesktopItems asar];

    desktopItems = [desktopItem];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ln -s ${fhs}/bin/antigravity-fhs $out/bin/antigravity

      # 2.0 icon is packed inside app.asar. `asar extract-file` writes to
      # cwd/<filename>, so cd into the output dir before extracting.
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      ( cd $out/share/pixmaps && \
        asar extract-file ${antigravity-unwrapped}/lib/antigravity/resources/app.asar icon.png && \
        mv icon.png antigravity.png )
      cp $out/share/pixmaps/antigravity.png \
        $out/share/icons/hicolor/1024x1024/apps/antigravity.png

      runHook postInstall
    '';
  };

  # ── Non-FHS variant ────────────────────────────────────────
  # Uses autoPatchelfHook instead of buildFHSEnv.
  # This avoids the bubblewrap sandbox that sets the kernel
  # "no new privileges" flag, which prevents sudo from working
  # in the integrated terminal.

  no-fhs-package = stdenv.mkDerivation {
    inherit pname version meta;
    src = finalSrc;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      copyDesktopItems
      asar
    ];

    buildInputs = runtimeLibs;

    runtimeDependencies = dlopenLibs;

    # Optional deps from the bundled Microsoft Authentication extension
    autoPatchelfIgnoreMissingDeps = [
      "libwebkit2gtk-4.1.so.0"
      "libsoup-3.0.so.0"
      "libcurl.so.4"
      "libcrypto.so.3"
    ];

    dontBuild = true;
    dontConfigure = true;

    # 2.0 dropped @vscode/sudo-prompt and adopted the standard Electron asar
    # layout (resources/app.asar + resources/app.asar.unpacked/). No patching
    # required — Electron handles the layout natively at runtime.

    desktopItems = [desktopItem];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity
      cp -r ./* $out/lib/antigravity/

      # 2.0: the launcher binary is at the tarball root, not under bin/.
      # No tunnel shim needed — 2.0 handles tunnel internally (or absence
      # thereof) without the 1.x ENOENT shim.
      #
      # We don't use makeWrapper here because Electron's bundled
      # electron-log transport writes synchronously to stdout, and when
      # the app is launched from a .desktop file (DE app menu) the parent
      # closes the inherited stdout pipe — first console.info() triggers
      # `Error: write EPIPE` from electron-log/src/node/transports/console.js
      # and crashes the main process. Redirecting stdout/stderr to
      # /dev/null when not attached to a TTY sidesteps this without
      # silencing terminal launches.
      mkdir -p $out/bin
      cat > $out/bin/antigravity <<EOF
      #!/usr/bin/env bash
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}
      if [ -t 1 ]; then
        exec "$out/lib/antigravity/antigravity" "\$@"
      else
        exec "$out/lib/antigravity/antigravity" "\$@" >/dev/null 2>&1
      fi
      EOF
      chmod +x $out/bin/antigravity

      # Icon is packed inside app.asar in 2.0 (was a loose file under
      # resources/app/resources/linux/ in 1.x). `asar extract-file` writes
      # to cwd/<filename>, so cd into the output dir before extracting.
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      ( cd $out/share/pixmaps && \
        asar extract-file $out/lib/antigravity/resources/app.asar icon.png && \
        mv icon.png antigravity.png )
      cp $out/share/pixmaps/antigravity.png \
        $out/share/icons/hicolor/1024x1024/apps/antigravity.png

      runHook postInstall
    '';
  };
in
  if useFHS
  then fhs-package
  else no-fhs-package
