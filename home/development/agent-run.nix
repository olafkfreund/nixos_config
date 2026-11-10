{ pkgs, lib, ... }:
let
  # The module system ignores argument defaults, so this is a binding; step 4 of the plan turns it on.
  agyMember = false;
  sandbox = import ./agent-sandbox-pkgs.nix { inherit pkgs lib; };
  testPath = lib.makeBinPath (with pkgs; [ bash coreutils util-linux procps jq socat gnugrep gnused gawk findutils diffutils git ]);
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
  herdr-team = pkgs.writeShellApplication {
    name = "herdr-team";
    runtimeInputs = with pkgs; [ jq coreutils util-linux procps git gnugrep gnused gawk findutils systemd ];
    text = "agy_member=${lib.boolToString agyMember}\nsink_path=${sandbox.herdr-team-sink}/bin/herdr-team-sink\n" + builtins.readFile ./herdr-team.sh;
    checkPhase = ''
      runHook preCheck
      ${pkgs.stdenv.shellDryRun} "$target"
      ${lib.getExe pkgs.shellcheck-minimal} --exclude=SC2016 "$target" # jq filters are single-quoted on purpose
      PATH=${testPath}:$PATH bash ${./herdr-team-test.sh} "$target" < /dev/null
      runHook postCheck
    '';
  };
in
{
  home.packages = [
    herdr-run
    herdr-team
    (pkgs.writeShellApplication {
      name = "agent-run";
      runtimeInputs = with pkgs; [ git jq coreutils gnugrep herdr-run ];
      text = builtins.readFile ./agent-run.sh;
    })
    sandbox.agent-review
    sandbox.herdr-team-sink
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
        names=$(AGENT_ENV_DECOY=1 NIX_CONFIG='access-tokens = github.com=decoy' HOME=/homeless \
          "$target" ${pkgs.coreutils}/bin/env -0 </dev/null | tr '\0' '\n' | cut -d= -f1)
        if grep -qx AGENT_ENV_DECOY <<<"$names"; then exit 1; fi
        if grep -qx NIX_CONFIG <<<"$names"; then exit 1; fi
        grep -qx HOME <<<"$names" || exit 1
        grep -qx PATH <<<"$names" || exit 1
        code=0; "$target" ${pkgs.bash}/bin/bash -c 'exit 7' </dev/null || code=$?
        [ "$code" = 7 ] || exit 1
        runHook postCheck
      '';
    })
    sandbox.agent-implement
  ];
}
