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
,
}:

let
  # Version from Anthropic's latest channel (matches npm)
  # Run `curl -fsSL "$GCS_BUCKET/latest"` to check latest
  version = "2.1.19";

  # Anthropic's official distribution bucket
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  # Platform-specific binary sources with checksums from manifest.json
  # Run ./scripts/update-claude-code-native.sh to update these
  sources = {
    x86_64-linux = {
      url = "${gcs_bucket}/${version}/linux-x64/claude";
      hash = "sha256-Tiocc4cezzsTM3a1fe0DMzp6Y4fy0qOmJ5u5Cgf3qUQ=";
    };
    aarch64-linux = {
      url = "${gcs_bucket}/${version}/linux-arm64/claude";
      hash = "sha256-jEthskynYNb3qi8ZcnFj0SLp/Qw86R8QaiG2kYp7G7s=";
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

    # Create wrapper with environment variables to disable auto-update
    makeWrapper $out/lib/claude-code/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER "1" \
      --set CLAUDE_CODE_SKIP_UPDATE_CHECK "1"

    runHook postInstall
  '';

  meta = with lib; {
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
    license = licenses.unfree; # Anthropic proprietary
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "claude";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
