# codex from upstream's release tree, so one version serves every consumer,
# nixarchy's included (#2501). Wired in through overlays/custom-packages.nix.
#
# The tree is installed untouched under libexec/: the app-server daemon compares
# the running executable with its staged copy, so a wrapper at the tree's own
# bin/codex breaks it. The guard in bin/codex sits outside (see codex-wrapper.sh).
#
# Update: ./scripts/update-codex-bin.sh --write latest
{ lib
, stdenvNoCC
, fetchurl
, runtimeShell
}:

let
  version = "0.166.0";

  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-HUSyi8SsmTfX01MiZLqmilB842SVag1Ou4VvMxze4lQ=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-eCG3fdouYoP7H2PzFlF3onHaiDPoV89nPGyhyds7/MY=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "codex-bin: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "codex-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${source.target}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";

  # Static musl binaries; fixup would also rewrite the tree the daemon checks.
  dontPatchELF = true;
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/codex $out/bin
    cp -a bin codex-package.json codex-path codex-resources $out/libexec/codex/
    substitute ${./codex-wrapper.sh} $out/bin/codex \
      --subst-var-by shell ${runtimeShell} \
      --subst-var-by real $out/libexec/codex/bin/codex
    chmod +x $out/bin/codex
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # Test the installed wrapper, so a bad substitution fails the build.
    sed "s|$out/libexec/codex/bin/codex|@real@|" $out/bin/codex > installed-wrapper.sh
    sh ${./guard-test.sh} installed-wrapper.sh
    $out/bin/codex --version | grep -F ${version}
    runHook postInstallCheck
  '';

  meta = {
    description = "OpenAI Codex CLI (upstream release binary, stdin-hang guard)";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
