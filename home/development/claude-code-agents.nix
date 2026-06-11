# Claude Code agent curation
#
# The ~/.claude/agents/ pack (hand-installed, syncthing-synced across hosts) is
# NOT Home-Manager-managed — making it nix-store symlinks would break syncthing
# (peers would get dangling links into this host's store). So instead of owning
# the files, we keep a declarative *disable list* and, on every activation, move
# any listed agent out of agents/ into agents-disabled/.
#
# This makes the curation reproducible (the list lives in Nix) and self-healing
# (if a peer re-syncs a disabled agent back, the next switch hides it again),
# while staying fully compatible with the syncthing-managed, mutable agents dir.
# Reversible: drop a name from the list and move its file back.
{ config
, lib
, ...
}:
let
  cfg = config.programs.claudeCode.agentCuration;
  disabledStr = lib.concatStringsSep " " cfg.disabledAgents;
in
{
  options.programs.claudeCode.agentCuration = {
    enable = lib.mkEnableOption "Claude Code agent curation (hide irrelevant agents)" // {
      default = true;
    };

    disabledAgents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # business / finance / marketing / legal
        "business-analyst"
        "content-marketer"
        "customer-support"
        "legal-advisor"
        "payment-integration"
        "quant-analyst"
        "risk-manager"
        "sales-automator"
        # languages not in this stack (keep python/rust/go/ts/js)
        "c-pro"
        "cpp-pro"
        "csharp-pro"
        "elixir-pro"
        "java-pro"
        "php-pro"
        "scala-pro"
        # mobile / games
        "ios-developer"
        "mobile-developer"
        "unity-developer"
        "minecraft-bukkit-pro"
        # data / ML / web / misc not core to this infra
        "api-documenter"
        "data-engineer"
        "data-scientist"
        "ml-engineer"
        "mlops-engineer"
        "graphql-architect"
        "legacy-modernizer"
        "frontend-developer"
        "ui-ux-designer"
      ];
      description = ''
        Agent names (without .md) to keep out of ~/.claude/agents/. On each
        activation they are moved to ~/.claude/agents-disabled/ if present.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.claudeAgentCuration = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      A="$HOME/.claude/agents"
      D="$HOME/.claude/agents-disabled"
      if [ -d "$A" ]; then
        mkdir -p "$D"
        for a in ${disabledStr}; do
          if [ -f "$A/$a.md" ]; then
            $DRY_RUN_CMD mv "$A/$a.md" "$D/"
          fi
        done
      fi
    '';
  };
}
