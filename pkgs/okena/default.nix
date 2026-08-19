{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, libxkbcommon
, libglvnd
, vulkan-loader
, wayland
, xorg
, dtach
}:
# Okena — native terminal multiplexer (tabs, splits, detachable windows) built
# in Rust on GPUI, the UI framework behind the Zed editor.
#
# Built from the upstream x86_64 release tarball rather than from source: the
# workspace pulls gpui and gpui_platform straight from the zed-industries/zed
# git repo, so a source build means vendoring Zed's tree and compiling all of
# GPUI. Same trade-off as pkgs/github-copilot-app and pkgs/claude-desktop-beta.
#
# Bump: `gh release view --repo contember/okena` for the tag, then re-prefetch
# okena-linux-x64.tar.gz and update version + hash.
let
  # GPUI resolves its GPU/Wayland stack with dlopen, so these never appear in
  # DT_NEEDED and autoPatchelf cannot see them — they go in LD_LIBRARY_PATH.
  runtimeLibs = [
    vulkan-loader # libvulkan.so.1 — GPUI's renderer
    libglvnd # libEGL.so.1
    wayland # libwayland-client.so.0, libwayland-egl.so.1
    libxkbcommon
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "okena";
  version = "0.28.0";

  src = fetchurl {
    url = "https://github.com/contember/okena/releases/download/v${finalAttrs.version}/okena-linux-x64.tar.gz";
    hash = "sha256-MImvbDLJ7Gbc1rwfNPqcTzNqutCLTdlmBXjCsWJlv7g=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  # DT_NEEDED entries of both binaries.
  buildInputs = [
    libxkbcommon
    xorg.libxcb
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 okena "$out/bin/okena"
    install -Dm755 okena-daemon "$out/bin/okena-daemon"
    install -Dm444 okena.desktop "$out/share/applications/okena.desktop"

    for icon in icons/app-icon-*.png; do
      size=''${icon##*app-icon-}
      size=''${size%.png}
      install -Dm444 "$icon" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/okena.png"
    done

    runHook postInstall
  '';

  # dtach is okena's preferred session-persistence backend (it auto-detects
  # dtach > tmux > screen); without it on PATH every terminal dies with the app.
  postFixup = ''
    for bin in okena okena-daemon; do
      wrapProgram "$out/bin/$bin" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
        --prefix PATH : "${lib.makeBinPath [ dtach ]}"
    done
  '';

  meta = {
    description = "Fast, native terminal multiplexer built in Rust with GPUI";
    homepage = "https://github.com/contember/okena";
    license = lib.licenses.mit;
    mainProgram = "okena";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
