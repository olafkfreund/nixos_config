{ pkgs, lib, ... }:
let
  testPath = lib.makeBinPath (with pkgs; [ bash coreutils util-linux procps jq socat gnugrep gnused gawk findutils diffutils ]);
  herdr-run = pkgs.writeShellApplication {
    name = "herdr-run";
    runtimeInputs = with pkgs; [ jq socat coreutils util-linux procps gawk gnused ];
    text = builtins.readFile ./herdr-run.sh;
    checkPhase = ''
      runHook preCheck
      ${pkgs.stdenv.shellDryRun} "$target"
      ${lib.getExe pkgs.shellcheck-minimal} "$target"
      PATH=${testPath}:$PATH bash ${./herdr-run-test.sh} "$target" < /dev/null
      runHook postCheck
    '';
  };
in
{
  home.packages = [
    herdr-run
    (pkgs.writeShellApplication {
      name = "agent-run";
      runtimeInputs = with pkgs; [ git jq coreutils gnugrep herdr-run ];
      text = builtins.readFile ./agent-run.sh;
    })
  ];
}
