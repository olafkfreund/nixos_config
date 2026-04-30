# Claude Code managed-settings.json
#
# Renders /etc/claude-code/managed-settings.json — Claude Code's highest-
# precedence config layer. The CLI reads this file but NEVER writes to it,
# making the read-only nix-store backing both safe and correct.
#
# Use this for settings the user must not be able to disable from the CLI
# (PARR hooks, baseline permissions, apiKeyHelper). User-scope preferences
# like statusLine and enabledPlugins should NOT live here — see the init-
# template pattern in home/development/claude-code-lsp.nix instead.
#
# Reference: https://code.claude.com/docs/en/settings.md
# Tracked in issue #398.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.modules.programs.claude-code-managed;

  # PARR Protocol Reminder Hook — kept identical to the script in
  # home/development/claude-code-lsp.nix so behaviour is unchanged when we
  # move the hook from user scope to managed scope.
  parrReminderScript = pkgs.writeShellScript "parr-reminder.sh" ''
        #!/usr/bin/env bash
        cat << 'PARR_EOF'
    <system-reminder>
    ## MANDATORY: Follow PARR Protocol for This Task

    You MUST structure your response using these phases:

    ### 🎯 PLAN (Before ANY action)
    - State the goal in one sentence
    - List steps with verification criteria
    - Identify approach, assumptions, and risks

    ### ⚡ ACT (Execute ONE step at a time)
    - Announce what you're doing
    - Execute exactly ONE step
    - Show output and verify checkpoint
    - NEVER chain commands without checking results

    ### 🔍 REFLECT (After EACH step)
    - Did it work? Compare expected vs actual
    - Any side effects?
    - Is the plan still valid?

    ### 🔄 REVISE (When needed)
    - If something failed, diagnose root cause
    - Update plan with new information
    - Consider alternative approaches

    ### ✅ COMPLETE (When done)
    - Summarize what was achieved
    - List files changed
    - Note any follow-up needed

    CRITICAL RULES:
    - NEVER skip the PLAN phase
    - NEVER execute multiple steps without reflection
    - STOP immediately if something unexpected happens
    - Ask for clarification if stuck after 2 attempts
    </system-reminder>
    PARR_EOF
  '';

  # Hooks contributed by the parrProtocol convenience flag, merged with
  # whatever the user supplies via cfg.settings.hooks.
  parrHooks = lib.optionalAttrs cfg.parrProtocol.enable {
    UserPromptSubmit = [{
      hooks = [{
        type = "command";
        command = toString parrReminderScript;
      }];
    }];
  };

  mergedSettings = lib.recursiveUpdate
    (cfg.settings // {
      hooks = (cfg.settings.hooks or { }) // parrHooks;
    })
    { };

  managedJson = pkgs.writeText "claude-code-managed-settings.json"
    (builtins.toJSON mergedSettings);
in
{
  options.modules.programs.claude-code-managed = {
    enable = lib.mkEnableOption "Claude Code managed-settings.json (read-only baseline)";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = lib.literalExpression ''
        {
          permissions.deny = [ "Bash(rm -rf /*)" ];
          apiKeyHelper = "/run/wrappers/bin/op-claude-key";
        }
      '';
      description = ''
        Settings to write into /etc/claude-code/managed-settings.json.
        Claude Code reads this with highest precedence and never writes back.
        Anything here is effectively unmodifiable from the CLI/UI.
      '';
    };

    parrProtocol.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Inject the PARR (Plan, Act, Reflect, Revise) UserPromptSubmit hook.
        Equivalent to the previous programs.claudeCode.hooks.enableParrProtocol
        option, but enforced from managed scope so the user cannot disable it
        by editing ~/.claude/settings.json.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."claude-code/managed-settings.json" = {
      source = managedJson;
      mode = "0644";
    };
  };
}
