# .claude/agents/*.md is the only agent definition source; agy and Codex get renders (#3267).
{ lib, pkgs, ... }:
let
  team = import ../../modules/programs/agent-team.nix;
  src = ../../.claude/agents;

  rendered = pkgs.runCommand "agent-definitions"
    {
      nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pyyaml ])) ];
      roles = builtins.toJSON team.roles;
    } ''
    python3 ${./agent-definitions.py} ${src} "$out"
    bash ${./agent-definitions.test.sh} ${./agent-definitions.py} ${./agent-definitions-fixtures}
  '';
in
{
  home.file.".codex/agents".source = "${rendered}/codex";

  # Real files, not store links: ~/.gemini is Syncthing-synced.
  home.activation.agentDefinitionsAgy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dir=$HOME/.gemini/agents
    $DRY_RUN_CMD mkdir -p "$dir"
    for f in ${rendered}/gemini/*.md; do
      cmp -s "$f" "$dir/''${f##*/}" || $DRY_RUN_CMD install -m 0644 "$f" "$dir/''${f##*/}"
    done
    for f in "$dir"/*; do
      name=''${f##*/}
      [[ -f $f && $name != *sync-conflict* && ! -e ${rendered}/gemini/$name ]] || continue
      if [[ $(sed -n 2p "$f") == "# managed by nixos_config agent-definitions (#3267)" ]]; then
        $DRY_RUN_CMD rm -f -- "$f"
      fi
    done
    # The one stray hand copy, matched by content.
    f=$dir/test-agent.md
    if [[ -f $f && $(sha256sum < "$f") == "f2605ee60bb0af1645fe25ad5a4056032d5808ba337377bb2f4a1da02ea73179  -" ]]; then
      $DRY_RUN_CMD rm -f -- "$f"
    fi
  '';
}
