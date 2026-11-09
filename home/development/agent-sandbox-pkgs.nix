# The sandbox wrappers (unused by default since #2812, kept for a revert) and the notify sink.
{ pkgs, lib }:
let
  herdr-team-sink = pkgs.writeShellApplication {
    name = "herdr-team-sink";
    runtimeInputs = with pkgs; [ jq coreutils ];
    text = builtins.readFile ./notify-sink.sh;
    checkPhase = ''
      runHook preCheck
      ${pkgs.stdenv.shellDryRun} "$target"
      ${lib.getExe pkgs.shellcheck-minimal} "$target"
      t=$(mktemp -d)
      mkdir "$t/turns"
      sed "s|/run/herdr-team/turns|$t/turns|" "$target" > "$t/sink"
      sink() { ${pkgs.bash}/bin/bash "$t/sink" "$1" </dev/null; }
      id=11111111-2222-3333-4444-555555555555
      payload() { printf '{"type":"%s","turn-id":"%s","input-messages":["a","b"],"last-assistant-message":"%s"}' "$1" "$2" "$3"; }

      sink "$(payload agent-turn-complete $id hi)"
      ${pkgs.jq}/bin/jq -e '.turn_id == "'$id'" and .input == "b" and .reply == "hi" and .source == "codex"' "$t/turns/$id.json"

      sink "$(payload agent-turn-complete $id other)"
      ${pkgs.jq}/bin/jq -e '.reply == "hi"' "$t/turns/$id.json"

      sink "$(payload something-else 22222222-2222-3333-4444-555555555555 x)"
      sink "$(payload agent-turn-complete ../../etc/passwd x)"
      sink "$(payload agent-turn-complete 33333333 x)"
      sink 'not json'
      sink ""
      ln -s /nonexistent "$t/turns/44444444-2222-3333-4444-555555555555.json"
      sink "$(payload agent-turn-complete 44444444-2222-3333-4444-555555555555 x)"
      ln -s "$t/victim" "$t/turns/.55555555-2222-3333-4444-555555555555.tmp"
      sink "$(payload agent-turn-complete 55555555-2222-3333-4444-555555555555 x)"
      [ ! -e "$t/victim" ]
      [ ! -e "$t/turns/55555555-2222-3333-4444-555555555555.json" ]
      [ "$(ls -A "$t/turns" | wc -l)" = 3 ]

      # an explicit turns dir: only a real 0700 directory owned by the caller
      mkdir -m 700 "$t/own" "$t/loose"
      chmod 755 "$t/loose"
      ln -s "$t/own" "$t/link"
      sink2() { ${pkgs.bash}/bin/bash "$t/sink" "$1" "$2" </dev/null; }
      sink2 "$t/own" "$(payload agent-turn-complete $id hi)"
      ${pkgs.jq}/bin/jq -e '.reply == "hi"' "$t/own/$id.json"
      sink2 "$t/loose" "$(payload agent-turn-complete $id hi)"
      sink2 "$t/link" "$(payload agent-turn-complete 66666666-2222-3333-4444-555555555555 hi)"
      [ -z "$(ls -A "$t/loose")" ]
      [ "$(ls -A "$t/own" | wc -l)" = 1 ]

      rm -rf "$t/turns"
      code=0; sink "$(payload agent-turn-complete $id hi)" || code=$?
      [ "$code" = 0 ]
      [ ! -e "$t/turns" ]
      runHook postCheck
    '';
  };
  # The wrappers pass the sink's store path to Codex as its notify command.
  sinkPath = "sink_path=${herdr-team-sink}/bin/herdr-team-sink\n";
in
{
  inherit herdr-team-sink;
  agent-review = pkgs.writeShellApplication {
    name = "agent-review";
    runtimeInputs = with pkgs; [ bubblewrap git coreutils ];
    text = sinkPath + builtins.readFile ./agent-sandbox.sh + builtins.readFile ./agent-review.sh;
  };
  agent-implement = pkgs.writeShellApplication {
    name = "agent-implement";
    runtimeInputs = with pkgs; [ bubblewrap git coreutils util-linux bash ];
    text = sinkPath + builtins.readFile ./agent-sandbox.sh + builtins.readFile ./agent-implement.sh;
  };
}
