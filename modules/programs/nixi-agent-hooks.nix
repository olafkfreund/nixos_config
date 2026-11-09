{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.nixiAgentHooks;

  # Agents whose approve and result hooks are installed.
  approveAgents = [ "codex" ]; # probes P1-P7 (#211, 2026-11-09): Codex passed; Claude failed P7 (first hook answer wins), agy has no hook
  has = a: elem a approveAgents;

  # One shell line for every hook: a no-op on hosts without nixi-companion.
  nixi = args: "sh -c 'command -v nixi-companion >/dev/null || exit 0; exec nixi-companion ${args}'";

  # Managed hook commands must sit under /etc/codex/hooks and take no arguments.
  codexHook = name: args: pkgs.writeShellScript name ''
    command -v nixi-companion >/dev/null || exit 0
    exec nixi-companion ${args}
  '';

  agyHookEntry = (pkgs.formats.json { }).generate "nixi-working-agy-hook.json" {
    nixi-working.PreInvocation = [{
      type = "command";
      # agy blocks on a failing hook and wants one JSON object on stdout.
      command = "sh -c 'command -v nixi-companion >/dev/null && nixi-companion attention --from agy --hook; echo \"{}\"'";
      timeout = 5;
    }];
  };

  codexEntry = event: name: timeout: ''

    [[hooks.${event}]]

    [[hooks.${event}.hooks]]
    type = "command"
    command = "/etc/codex/hooks/${name}"
    timeout = ${toString timeout}
  '';
in
{
  options.features.nixiAgentHooks.enable = mkEnableOption "Nixi hooks for Claude Code, Codex and agy (approve, result, working signal; #211)";

  config = mkIf cfg.enable {
    modules.programs.claude-code-managed.extraHooks = {
      UserPromptSubmit = [{ hooks = [{ type = "command"; command = nixi "attention --from claude --hook"; timeout = 5; }]; }];
    } // optionalAttrs (has "claude") {
      PermissionRequest = [{ hooks = [{ type = "command"; command = nixi "approve --from claude"; timeout = 75; }]; }];
      PostToolUse = [{ hooks = [{ type = "command"; command = nixi "result --from claude"; timeout = 5; }]; }];
      PostToolUseFailure = [{ hooks = [{ type = "command"; command = nixi "result --from claude"; timeout = 5; }]; }];
    };

    environment.etc."codex/hooks/nixi-working".source = codexHook "nixi-working" "attention --from codex --hook";
    environment.etc."codex/hooks/nixi-approve" = mkIf (has "codex") { source = codexHook "nixi-approve" "approve --from codex"; };
    environment.etc."codex/hooks/nixi-result" = mkIf (has "codex") { source = codexHook "nixi-result" "result --from codex"; };
    environment.etc."codex/requirements.toml".text = mkAfter (
      codexEntry "UserPromptSubmit" "nixi-working" 5
      + optionalString (has "codex") (codexEntry "PermissionRequest" "nixi-approve" 75 + codexEntry "PostToolUse" "nixi-result" 5)
    );

    # ~/.gemini is Syncthing-synced, so merge into hooks.json instead of
    # replacing it. Writes go through a temp file so a dry run publishes nothing.
    home-manager.users.olafkfreund = { lib, ... }: {
      home.activation.nixiAgentAgyHook = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        hooksfile="$HOME/.gemini/config/hooks.json"
        jq=${pkgs.jq}/bin/jq
        if [ -f "$hooksfile" ] && $jq -e 'type == "object"' "$hooksfile" >/dev/null 2>&1; then
          if ! $jq -e --slurpfile want ${agyHookEntry} '."nixi-working" == $want[0]."nixi-working"' "$hooksfile" >/dev/null 2>&1; then
            tmp=$(mktemp)
            $jq -s '.[0] + .[1]' "$hooksfile" ${agyHookEntry} > "$tmp"
            $DRY_RUN_CMD mv "$tmp" "$hooksfile"
          fi
        fi
      '';
    };
  };
}
