{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.claudeSwarmReaper;
  reaper = "${pkgs.customPkgs.claude-swarm-reaper}/bin/claude-swarm-reaper";
  # PreToolUse fires on every tool call in every session: only swarm panes may
  # pay for a Python start, everything else returns from the shell at once.
  hookScript = kind: pkgs.writeShellScript "claude-swarm-hook-${kind}" ''
    case "''${TMUX:-}" in
      */claude-swarm-*) exec ${reaper} hook ${kind} ;;
    esac
    cat >/dev/null 2>&1
    exit 0
  '';
  hook = kind: [{ hooks = [{ type = "command"; command = "${hookScript kind}"; timeout = 5; }]; }];
in
{
  options.features.claudeSwarmReaper = {
    enable = mkEnableOption "reaping orphaned and idle Claude Code swarm tmux servers";
    idleMinutes = mkOption { type = types.int; default = 10; description = "Minutes a teammate may sit idle before its pane is killed."; };
    intervalMinutes = mkOption { type = types.int; default = 2; description = "How often the reaper runs."; };
    dryRun = mkOption { type = types.bool; default = true; description = "Log what would be killed and kill nothing."; };
  };

  config = mkIf cfg.enable {
    # A user unit on purpose: it must reach the user's tmux sockets, so the
    # DynamicUser/ProtectHome rule does not apply (the agent-say precedent).
    systemd.user.services.claude-swarm-reaper = {
      description = "Reap orphaned and idle Claude Code swarm tmux servers";
      serviceConfig = {
        Type = "oneshot";
        SyslogIdentifier = "claude-swarm-reaper";
        NoNewPrivileges = true;
        ExecStart = "${reaper} reap ${optionalString cfg.dryRun "--dry-run "}--idle-minutes ${toString cfg.idleMinutes}";
      };
    };

    systemd.user.timers.claude-swarm-reaper = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "${toString cfg.intervalMinutes}min";
      };
    };

    modules.programs.claude-code-managed.settings.hooks = {
      TeammateIdle = hook "idle";
      UserPromptSubmit = hook "active";
      PreToolUse = hook "active";
    };
  };
}
