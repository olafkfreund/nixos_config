{ stdenvNoCC
, claude-code-native
,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-code-mods";
  version = "0.2.0";
  src = ./.;
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME=$TMPDIR
    for p in fleet-guard nix-flavour; do
      ${claude-code-native}/bin/claude plugin validate ./$p
      ${claude-code-native}/bin/claude plugin test ./$p
    done
    runHook postCheck
  '';
  installPhase = ''
    mkdir -p $out
    cp -r ${./.}/. $out/
    rm -f $out/default.nix
  '';
}
