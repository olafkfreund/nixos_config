{ pkgs, lib, ... }:
let
  testPath = lib.makeBinPath (with pkgs; [ bash coreutils util-linux procps jq socat gnugrep gnused gawk findutils diffutils ]);
  herdr-run = pkgs.writeShellApplication {
    name = "herdr-run";
    runtimeInputs = with pkgs; [ jq socat coreutils util-linux procps gawk gnused ];
    text = builtins.readFile ./agent-env.sh + builtins.readFile ./herdr-run.sh;
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
    (pkgs.writeShellApplication {
      name = "agent-review";
      runtimeInputs = with pkgs; [ bubblewrap git coreutils ];
      text = builtins.readFile ./agent-sandbox.sh + builtins.readFile ./agent-review.sh;
    })
    (pkgs.writeShellApplication {
      name = "agent-env";
      text = builtins.readFile ./agent-env.sh + ''
        args=()
        while IFS= read -r -d "" name; do args+=("$name=''${!name}"); done < <(agent_env_exported)
        exec env -i "''${args[@]}" "$@"
      '';
      checkPhase = ''
        runHook preCheck
        ${pkgs.stdenv.shellDryRun} "$target"
        ${lib.getExe pkgs.shellcheck-minimal} "$target"
        names=$(AGENT_ENV_DECOY=1 HOME=/homeless "$target" ${pkgs.coreutils}/bin/env -0 </dev/null |
          tr '\0' '\n' | cut -d= -f1)
        if grep -qx AGENT_ENV_DECOY <<<"$names"; then exit 1; fi
        grep -qx HOME <<<"$names" || exit 1
        grep -qx PATH <<<"$names" || exit 1
        code=0; "$target" ${pkgs.bash}/bin/bash -c 'exit 7' </dev/null || code=$?
        [ "$code" = 7 ] || exit 1
        runHook postCheck
      '';
    })
    (pkgs.writeShellApplication {
      name = "agent-implement";
      runtimeInputs = with pkgs; [ bubblewrap git coreutils util-linux bash ];
      text = builtins.readFile ./agent-sandbox.sh + builtins.readFile ./agent-implement.sh;
    })
  ];
}
