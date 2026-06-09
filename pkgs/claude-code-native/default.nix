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
, writeScriptBin
,
}:

let
  # Version from Anthropic's latest channel (matches npm)
  # Run `curl -fsSL "$GCS_BUCKET/latest"` to check latest
  version = "2.1.170";

  # Shim that intercepts wl-paste's `-l`/`--list-types` call used by Claude
  # Code's background clipboard-image polling.  Returning an empty type list
  # tells Claude no images are in the clipboard so it never spawns persistent
  # wl-paste processes — those create xdg_toplevel windows visible in GNOME's
  # dock.  All other wl-paste calls (e.g. text paste) forward to the real binary.
  wlPasteShim = writeScriptBin "wl-paste" ''
    for arg in "$@"; do
      case "$arg" in
        -l|--list-types) exit 0 ;;
      esac
    done
    exec ${wl-clipboard}/bin/wl-paste "$@"
  '';

  # Anthropic's official distribution bucket
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  # Platform-specific binary sources with checksums from manifest.json
  # Run ./scripts/update-claude-code-native.sh to update these
  sources = {
    x86_64-linux = {
      url = "${gcs_bucket}/${version}/linux-x64/claude";
      hash = "sha256-hJ4AcnegRCqydXDT49bUN4dQeUZZDo3RlH5aObcIH54=";
    };
    aarch64-linux = {
      url = "${gcs_bucket}/${version}/linux-arm64/claude";
      hash = "sha256-G7nQMkQKdVMvfdTK+8aH8iCq8Wxj66F+GS377C8EvSU=";
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

    # Create wrapper: disable auto-update and prepend wl-paste shim so the
    # clipboard-image polling returns an empty type list instead of spawning
    # real wl-paste processes (which create GNOME dock windows on Wayland).
    makeWrapper $out/lib/claude-code/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER "1" \
      --set CLAUDE_CODE_SKIP_UPDATE_CHECK "1" \
      --prefix PATH : ${wlPasteShim}/bin

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
