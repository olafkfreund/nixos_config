# warp-terminal — custom-tracked latest stable.
#
# Mirrors upstream nixpkgs pkgs/by-name/wa/warp-terminal/package.nix, minus
# Darwin (we don't run macOS hosts). versions.json is bumped by
# ../../scripts/update-warp-terminal.sh, which is also wired in as
# passthru.updateScript. Run it before `nhs <host>` whenever you want the
# latest Warp release.
#
# Registered as an overlay in flake.nix so pkgs.warp-terminal everywhere in
# the repo (notably home/desktop/terminals/warp/default.nix) resolves here.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, zstd
, alsa-lib
, curl
, fontconfig
, libglvnd
, libxkbcommon
, vulkan-loader
, wayland
, xdg-utils
, libxi
, libxcursor
, libx11
, libxcb
, xz
, # liblzma
  zlib
, makeWrapper
, waylandSupport ? false
,
}:

let
  pname = "warp-terminal";
  versions = lib.importJSON ./versions.json;

  linux_arch = if stdenv.hostPlatform.system == "x86_64-linux" then "x86_64" else "aarch64";
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (versions."linux_${linux_arch}") version;

  src = fetchurl {
    inherit (versions."linux_${linux_arch}") hash;
    url = "https://releases.warp.dev/stable/v${finalAttrs.version}/warp-terminal-v${finalAttrs.version}-1-${linux_arch}.pkg.tar.zst";
  };

  sourceRoot = ".";

  postPatch = ''
    substituteInPlace usr/bin/warp-terminal \
      --replace-fail /opt/ $out/opt/
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    zstd
    makeWrapper
  ];

  buildInputs = [
    alsa-lib # libasound.so.2
    curl
    fontconfig
    (lib.getLib stdenv.cc.cc) # libstdc++.so libgcc_s.so
    zlib
    xz
  ];

  runtimeDependencies = [
    libglvnd # for libegl
    libxkbcommon
    stdenv.cc.libc
    vulkan-loader
    xdg-utils
    libx11
    libxcb
    libxcursor
    libxi
  ]
  ++ lib.optionals waylandSupport [ wayland ];

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -r opt usr/* $out

  ''
  + lib.optionalString waylandSupport ''
    wrapProgram $out/bin/warp-terminal --set WARP_ENABLE_WAYLAND 1
  ''
  + ''
    runHook postInstall
  '';

  postFixup = ''
    # https://github.com/warpdotdev/Warp/issues/5793
    patchelf \
      --add-needed libfontconfig.so.1 \
      $out/opt/warpdotdev/warp-terminal/warp
  '';

  passthru.updateScript = ../../scripts/update-warp-terminal.sh;

  meta = {
    description = "Rust-based terminal (custom-tracked latest stable)";
    homepage = "https://www.warp.dev";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "warp-terminal";
  };
})
