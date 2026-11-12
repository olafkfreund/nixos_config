# nixarchy-llm-index: local document and code index served to agents over MCP
# (#2882). ~/Source is public, ~/Documents private; only the public server is
# registered, in Claude Code, Codex and agy, by the converging activation below.
{ inputs, ... }:
{
  home-manager.users.olafkfreund =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.llm-index;
      jq = "${pkgs.jq}/bin/jq";
      want = cfg.mcpServers.public;
      wantJson = builtins.toJSON { inherit (want) command args; };
    in
    {
      imports = [ inputs.nixarchy-llm-index.homeManagerModules.default ];

      services.llm-index = {
        enable = true;
        roots = {
          source = {
            path = "/mnt/code/Source-home"; # real path; ~/Source is a symlink
            tier = "public";
          };
          docs.path = "${config.home.homeDirectory}/Documents"; # private by default
        };
        limits.memoryMaxMb = 2048; # the 1 GB default throttled at 768 MB in the trial
      };

      home.packages = [ cfg.package ];
      home.file.".claude/rules/llm-index.md".text = cfg.agentInstructions;

      # Converge each client's `llm-index` entry on the current store path; write only
      # on a difference. Never `exit`: activation entries are one script.
      home.activation.llmIndexMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _llm_want=$(echo ${lib.escapeShellArg wantJson} | ${jq} -cS .)
        for _llm_c in claude codex agy; do
          _llm_b=""
          for _llm_d in "${config.home.profileDirectory}/bin" /run/current-system/sw/bin; do
            if [ -x "$_llm_d/$_llm_c" ]; then _llm_b="$_llm_d/$_llm_c"; break; fi
          done
          [ -n "$_llm_b" ] || continue
          # Read the current entry. A read error skips the client; only "no entry" or a
          # different entry leads to a write, so a broken read never removes anything.
          _llm_ok=1
          case "$_llm_c" in
            claude) _llm_f="$HOME/.claude.json" ;;
            agy) _llm_f="$HOME/.gemini/config/mcp_config.json" ;;
            codex) _llm_f="" ;;
          esac
          if [ -n "$_llm_f" ]; then
            if [ ! -e "$_llm_f" ]; then _llm_have=""
            else _llm_have=$(${jq} -cS '.mcpServers["llm-index"] // empty | {command, args}' "$_llm_f") || _llm_ok=0
            fi
          else
            _llm_have=$("$_llm_b" mcp list --json | ${jq} -cS '.[] | select(.name == "llm-index") | .transport | {command, args}') || _llm_ok=0
          fi
          if [ "$_llm_ok" != 1 ]; then
            echo "llm-index: could not read the $_llm_c MCP config; left unchanged"
          elif [ "$_llm_have" != "$_llm_want" ]; then
            _llm_s=""; [ "$_llm_c" = claude ] && _llm_s="-s user"
            if [ -n "''${DRY_RUN_CMD:-}" ]; then
              echo "llm-index: would register in $_llm_c"
            else
              # An entry is removed only when one exists; a failed add is retried next activation.
              [ -z "$_llm_have" ] || "$_llm_b" mcp remove $_llm_s llm-index >/dev/null 2>&1 || true
              if "$_llm_b" mcp add $_llm_s llm-index -- ${lib.escapeShellArgs ([ want.command ] ++ want.args)} >/dev/null 2>&1; then
                echo "llm-index: registered in $_llm_c"
              else
                echo "llm-index: could not register in $_llm_c"
              fi
            fi
          fi
        done
      '';
    };
}
