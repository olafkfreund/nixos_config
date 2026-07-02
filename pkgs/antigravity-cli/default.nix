{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
,
}:
# Google Antigravity CLI (`agy`) — the replacement for Gemini CLI.
#
# Single dynamically-linked Go binary distributed via a manifest at:
#   https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
# That manifest yields the canonical tarball URL (which we pin here).
#
# To bump: fetch the manifest, copy `version` + `url`, then prefetch
# the tarball:
#   curl -s https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
#   nix-prefetch-url --type sha256 <url from manifest>
#
# We skip upstream's install.sh path-snippet handoff (`agy install`)
# because Nix manages PATH. The binary is renamed from `antigravity` →
# `agy` (matching upstream's install convention so user docs/migration
# instructions still apply).
#
# Closed-source proprietary Google binary, license is unfree.
stdenv.mkDerivation {
  pname = "antigravity-cli";
  version = "1.0.14-6049473256882176";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.14-6049473256882176/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-cXDVmBk+4K3cq6fYw6LC4weuhiLaz3SYMRKL0a08pFg=";
  };

  # Tarball contains a single file `antigravity` at the root.
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib # provides libgcc_s
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ./antigravity $out/bin/agy

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Antigravity CLI (agy) — agent-first replacement for Gemini CLI";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
