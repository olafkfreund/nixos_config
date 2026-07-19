# Claude Code Native Binary Package
#
# This package downloads pre-built Claude Code binaries from Anthropic's
# official distribution channel and patches them for NixOS compatibility.
#
# Benefits over npm-based package:
# - No Node.js runtime dependency
# - Faster startup time
# - Smaller closure size
# - Direct binary execution
#
# Update process:
# 1. Run: ./scripts/update-claude-code-native.sh
# 2. Update version and hashes below
# 3. Test: nix build .#claude-code-native
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, openssl
, zlib
, glibc
, wl-clipboard
, xclip
, coreutils
, writeScriptBin
,
}:

let
  # Version from Anthropic's latest channel (matches npm)
  # Run `curl -fsSL "$GCS_BUCKET/latest"` to check latest
  version = "2.1.215";

  # Claude Code reads clipboard images by shelling out to:
  #   xclip -selection clipboard -t TARGETS -o ... || wl-paste -l ...   (detect)
  #   wl-paste --type image/png  /  xclip ... -t image/bmp -o           (retrieve)
  #
  # On GNOME/Mutter (no wlr-data-control / ext-data-control protocol) wl-paste
  # has to fake an xdg_toplevel and wait for keyboard focus. It frequently never
  # gets focus and BLOCKS FOREVER — the hung process shows up as a persistent
  # "wl-clipboard" window in the GNOME dock and steals focus from the terminal.
  #
  # The previous shim avoided that by forcing `wl-paste -l` to return an empty
  # type list — but that also told Claude "no image in clipboard", which is why
  # image paste was completely broken (#XXX).
  #
  # New approach: forward EVERY call to the real wl-paste but wrap it in a 2s
  # timeout. Detection (`-l`) and retrieval (`--type ...`) return real data when
  # Mutter cooperates, but can never hang — worst case the dummy dock window
  # flashes for <=2s during an actual paste, then disappears. Claude still tries
  # xclip (XWayland) first, so this fallback usually isn't even reached.
  wlPasteShim = writeScriptBin "wl-paste" ''
    exec ${coreutils}/bin/timeout 2 ${wl-clipboard}/bin/wl-paste "$@"
  '';

  # Anthropic's official distribution bucket
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  # Platform-specific binary sources with checksums from manifest.json
  # Run ./scripts/update-claude-code-native.sh to update these
  sources = {
    x86_64-linux = {
      url = "${gcs_bucket}/${version}/linux-x64/claude";
      hash = "sha256-we//qvNwqhh8tqCd2T1OURxkaJmwB4R2+DeRtmS95/4=";
    };
    aarch64-linux = {
      url = "${gcs_bucket}/${version}/linux-arm64/claude";
      hash = "sha256-K0Oj1bB4chfl1zgfrULHMUKSVG/p2564ubN53pBQmzA=";
    };
  };

  currentSource = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}. Supported: x86_64-linux, aarch64-linux");
in
stdenv.mkDerivation {
  pname = "claude-code-native";
  inherit version;

  src = fetchurl {
    url = currentSource.url;
    hash = currentSource.hash;
    # The binary is downloaded as-is, no archive extraction
    name = "claude-${version}-${stdenv.hostPlatform.system}";
  };

  # Don't try to unpack - it's a single binary
  dontUnpack = true;

  # Don't try to strip - binary is already optimized
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Runtime dependencies for the binary
  # autoPatchelfHook will automatically find and link these
  buildInputs = [
    openssl
    zlib
    glibc
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    # Create output directories
    mkdir -p $out/bin
    mkdir -p $out/lib/claude-code

    # Install the binary
    cp $src $out/lib/claude-code/claude
    chmod +x $out/lib/claude-code/claude

    # Create wrapper: disable auto-update and prepend the clipboard tools.
    # - xclip: Claude's preferred (XWayland) image-paste path; reliable and never
    #   spawns a GNOME dock window. Put it first so detection short-circuits here.
    # - wlPasteShim: timeout-guarded wl-paste fallback that can detect/retrieve
    #   images without hanging the dock (see comment above).
    makeWrapper $out/lib/claude-code/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER "1" \
      --set CLAUDE_CODE_SKIP_UPDATE_CHECK "1" \
      --prefix PATH : ${lib.makeBinPath [ xclip wlPasteShim ]}

    runHook postInstall
  '';

  meta = {
    description = "Claude Code CLI - Native binary (Anthropic's AI coding assistant)";
    longDescription = ''
      Claude Code is Anthropic's official CLI tool for AI-assisted coding.
      This package provides the native pre-built binary, which offers:
      - No Node.js runtime dependency
      - Faster startup times
      - Direct binary execution
      - Smaller closure size

      For the npm-based version, use the claude-code package instead.
      Both packages track the latest version (${version}).
    '';
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree; # Anthropic proprietary
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "claude";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
