_final: prev:
let
  mkCmakePolicyFix = pkgName:
    prev.${pkgName}.overrideAttrs (oldAttrs: {
      cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      ];
    });
in
{
  clblast = mkCmakePolicyFix "clblast";
  cld2 = mkCmakePolicyFix "cld2";
  ctranslate2 = mkCmakePolicyFix "ctranslate2";
  rofi-file-browser-extended = mkCmakePolicyFix "rofi-file-browser-extended";
  birdtray = mkCmakePolicyFix "birdtray";
  allegro = mkCmakePolicyFix "allegro";

  ltrace = prev.ltrace.overrideAttrs (_oldAttrs: {
    doCheck = false;
  });

  mu = prev.mu.overrideAttrs (_oldAttrs: {
    doCheck = false;
  });

  cxxopts = prev.cxxopts.overrideAttrs (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.icu ];
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ prev.icu ];
  });

  pamixer = prev.pamixer.overrideAttrs (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.cxxopts prev.icu ];
  });
}
