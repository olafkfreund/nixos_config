{ lib
, stdenv
, fetchurl
, runCommand
, writeText
}:
# herdr-core (hc) — the headless server that owns Herdr's terminals and agents.
#
# Upstream static-pie x86_64 tarball: no patchelf, and stripping would break it.
#
# Bump: version + sha256 from https://releases.herdr.dev/core/latest.json, then
# re-run Verification 2-7 and 9 on p620. Check that a running old server keeps
# its terminals across `hc server restart`.
let
  version = "0.1.20";

  frontmatter = writeText "herdr-core-skill-frontmatter" ''
    ---
    name: hc
    description: "Run and steer long-lived terminals and coding agents with herdr-core (hc): hc run, send, wait, read, attach. Use when the user mentions hc or herdr-core. Not the Herdr TUI (that is the herdr skill)."
    ---
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-core";
  inherit version;

  src = fetchurl {
    url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-x86_64.tar.gz";
    sha256 = "ac6b86890c451a37584620aaa438b71bc0d0bd430a2e7c1d7e095f052c414e74";
  };

  sourceRoot = ".";

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 herdr-core "$out/bin/herdr-core"
    ln -s herdr-core "$out/bin/hc"
    install -Dm444 LICENSE THIRD-PARTY-NOTICES -t "$out/share/doc/herdr-core"

    runHook postInstall
  '';

  passthru.skill = runCommand "herdr-core-skill" { } ''
    mkdir -p $out
    { cat ${frontmatter}; HOME=$TMPDIR ${finalAttrs.finalPackage}/bin/herdr-core --skill; } > $out/SKILL.md
  '';

  meta = {
    description = "Headless server for Herdr terminals and coding agents (hc)";
    homepage = "https://herdr.dev";
    license = lib.licenses.asl20;
    mainProgram = "hc";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
