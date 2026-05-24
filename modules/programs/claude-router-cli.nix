# Claude Code router CLI — switches repos between local Ollama (via LiteLLM
# on p620) and cloud Anthropic API per repository.
#
# Phase 3 of docs/plans/2026-05-22-ollama-p620-litellm-design.md. Depends
# on Phase 1 (Ollama on p620) + Phase 2 (LiteLLM proxy on p620).
#
# What this module installs:
#
# 1. `claude-router` CLI on system PATH:
#      claude-router use-ollama   — writes <repo>/.claude/settings.json with
#                                   ANTHROPIC_BASE_URL pointing at the right
#                                   router URL (loopback on p620, Tailscale on razer)
#      claude-router use-claude   — removes the override (back to api.anthropic.com)
#      claude-router use-default  — alias for use-claude
#      claude-router status       — prints which backend the current repo uses
#
# 2. `claude-router-key` helper script for Claude Code's apiKeyHelper:
#    inspects ANTHROPIC_BASE_URL and emits the right bearer key:
#      - router URL  → /run/agenix/api-router-<host>   (LiteLLM bearer)
#      - default URL → /run/agenix/api-anthropic       (cloud Anthropic)
#    This is auto-wired into modules.programs.claude-code-managed.settings.apiKeyHelper.
#
# 3. Slash command markdown files at /etc/claude-code/commands/ for users who
#    want the slash-command UX. Home Manager users can symlink them into
#    ~/.claude/commands/ (a HM stanza is provided in the user's profile for
#    olafkfreund — see Users/olafkfreund/profile.nix).
#
# Network endpoint selection happens at write-time in `claude-router use-ollama`:
#   - on p620   → http://127.0.0.1:4000          (loopback, sub-ms)
#   - elsewhere → https://p620.<tailnet>.ts.net/router (Tailscale)
#
# The bearer key for the router and the key for cloud Anthropic are BOTH
# agenix-managed; the user never types them.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.modules.programs.claude-router-cli;

  # The router URL emitted for `use-ollama`. Computed at activation time
  # from the current host's name — p620 uses loopback, everyone else uses
  # Tailscale-serve.
  #
  # The trailing /router is the Tailscale-serve path; loopback has no path
  # prefix since LiteLLM owns the whole port.
  routerUrl = ''
    if [[ "$(hostname)" == "p620" ]]; then
      echo "http://127.0.0.1:4000"
    else
      echo "https://p620.tail833f7.ts.net/router"
    fi
  '';

  claudeRouter = pkgs.writeShellApplication {
    name = "claude-router";
    runtimeInputs = with pkgs; [ git jq ];
    text = ''
      set -euo pipefail

      cmd="''${1:-status}"

      # Find the repo root (or pwd if not in a git repo)
      if root=$(git rev-parse --show-toplevel 2>/dev/null); then
        :
      else
        root="$PWD"
      fi
      settings_file="$root/.claude/settings.json"

      router_url() {
        ${routerUrl}
      }

      case "$cmd" in
        use-ollama)
          url="$(router_url)"
          mkdir -p "$root/.claude"
          # Preserve any existing settings; just set/override the env block and apiKeyHelper.
          if [[ -f "$settings_file" ]]; then
            jq --arg url "$url" --arg helper "${lib.getExe claudeRouterKey}" \
              '.env = (.env // {}) | .env.ANTHROPIC_BASE_URL = $url | del(.env.CLAUDE_ROUTER_MODE) | .apiKeyHelper = $helper | .model = "claude-sonnet-4-6"' \
              "$settings_file" > "$settings_file.tmp"
            mv "$settings_file.tmp" "$settings_file"
          else
            jq -n --arg url "$url" --arg helper "${lib.getExe claudeRouterKey}" \
              '{env: {ANTHROPIC_BASE_URL: $url}, apiKeyHelper: $helper, model: "claude-sonnet-4-6"}' \
              > "$settings_file"
          fi
          echo "✓ $root now uses Ollama via $url"
          ;;

        use-subscription|use-default)
          if [[ -f "$settings_file" ]]; then
            # Revert to default behavior (subscription) by removing overrides and the apiKeyHelper
            jq 'del(.apiKeyHelper) | if .env then del(.env.ANTHROPIC_BASE_URL) | del(.env.CLAUDE_ROUTER_MODE) | (if (.env | length) == 0 then del(.env) else . end) else . end | del(.model)' \
              "$settings_file" > "$settings_file.tmp"
            # If the file is now {}, remove it entirely.
            if [[ "$(jq -c . "$settings_file.tmp")" == "{}" ]]; then
              rm -f "$settings_file" "$settings_file.tmp"
              echo "✓ $root reset to default (Cloud Subscription) — settings file removed"
            else
              mv "$settings_file.tmp" "$settings_file"
              echo "✓ $root reset to default (Cloud Subscription) — router overrides cleared"
            fi
          else
            echo "✓ $root already uses default (Cloud Subscription)"
          fi
          ;;

        use-api|use-claude)
          mkdir -p "$root/.claude"
          if [[ -f "$settings_file" ]]; then
            jq --arg helper "${lib.getExe claudeRouterKey}" \
              '.env = (.env // {}) | .env.CLAUDE_ROUTER_MODE = "api" | del(.env.ANTHROPIC_BASE_URL) | .apiKeyHelper = $helper | del(.model)' \
              "$settings_file" > "$settings_file.tmp"
            mv "$settings_file.tmp" "$settings_file"
          else
            jq -n --arg helper "${lib.getExe claudeRouterKey}" \
              '{env: {CLAUDE_ROUTER_MODE: "api"}, apiKeyHelper: $helper}' > "$settings_file"
          fi
          echo "✓ $root now uses Anthropic Cloud API key (usage-based billing)"
          ;;

        status)
          url="''${ANTHROPIC_BASE_URL:-}"
          mode="''${CLAUDE_ROUTER_MODE:-}"
          if [[ -f "$settings_file" ]]; then
            if [[ -z "$url" ]]; then
              url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$settings_file")
            fi
            if [[ -z "$mode" ]]; then
              mode=$(jq -r '.env.CLAUDE_ROUTER_MODE // empty' "$settings_file")
            fi
          fi
          if [[ -n "$url" ]]; then
            echo "ollama via $url"
          elif [[ "$mode" == "api" ]]; then
            echo "api key (cloud Anthropic) — usage-based billing"
          else
            echo "subscription (cloud Anthropic) — default"
          fi
          ;;

        *)
          echo "usage: claude-router {use-ollama|use-api|use-claude|use-subscription|use-default|status}" >&2
          exit 2
          ;;
      esac
    '';
  };

  # apiKeyHelper script. Claude Code invokes this to fetch the bearer
  # token for the current session. We check ANTHROPIC_BASE_URL and emit
  # the matching key file's contents.
  #
  # Match :4000 specifically OR the Tailscale /router path — avoids false
  # positives from other p620 URLs (e.g. binary cache on :5000).
  claudeRouterKey = pkgs.writeShellApplication {
    name = "claude-router-key";
    runtimeInputs = with pkgs; [ coreutils jq ];
    text = ''
      set -euo pipefail
      url="''${ANTHROPIC_BASE_URL:-}"
      mode="''${CLAUDE_ROUTER_MODE:-}"

      # Search up the directory tree if either var is empty
      curr_dir="$PWD"
      while [[ "$curr_dir" != "/" ]]; do
        if [[ -f "$curr_dir/.claude/settings.json" ]]; then
          if [[ -z "$url" ]]; then
            url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$curr_dir/.claude/settings.json")
          fi
          if [[ -z "$mode" ]]; then
            mode=$(jq -r '.env.CLAUDE_ROUTER_MODE // empty' "$curr_dir/.claude/settings.json")
          fi
        fi
        curr_dir="$(dirname "$curr_dir")"
      done

      if [[ "$url" == *:4000* ]] || [[ "$url" == *p620.*ts.net/router* ]]; then
        if [[ -f "/run/agenix/api-router-$(hostname)" ]]; then
          tr -d '\n' < "/run/agenix/api-router-$(hostname)"
        else
          echo "Error: Router key secret not found" >&2
          exit 1
        fi
      elif [[ "$mode" == "api" ]]; then
        # API key mode explicitly requested
        if [[ -f "/run/agenix/api-anthropic" ]]; then
          tr -d '\n' < "/run/agenix/api-anthropic"
        else
          # Fallback if no API key exists
          exit 0
        fi
      else
        # Default behavior: Cloud Subscription mode (output nothing, exit 0)
        exit 0
      fi
    '';
  };

  # Slash command markdown files. Installed under /etc/claude-code/commands/;
  # users who want slash-command UX symlink them into ~/.claude/commands/.
  slashCommands = pkgs.runCommand "claude-router-slash-commands" { } ''
    mkdir -p "$out/commands"

    cat > "$out/commands/use-ollama.md" <<'EOF'
    ---
    description: Switch this repo to the local Ollama backend (via LiteLLM on p620)
    allowed-tools: Bash(claude-router:*)
    ---

    !`claude-router use-ollama`
    EOF

    cat > "$out/commands/use-subscription.md" <<'EOF'
    ---
    description: Switch this repo to Anthropic Cloud Subscription (default)
    allowed-tools: Bash(claude-router:*)
    ---

    !`claude-router use-subscription`
    EOF

    cat > "$out/commands/use-claude.md" <<'EOF'
    ---
    description: Switch this repo to cloud Anthropic API key (usage-based billing)
    allowed-tools: Bash(claude-router:*)
    ---

    !`claude-router use-claude`
    EOF

    cat > "$out/commands/use-default.md" <<'EOF'
    ---
    description: Reset this repo to default backend (Cloud Subscription)
    allowed-tools: Bash(claude-router:*)
    ---

    !`claude-router use-default`
    EOF

    cat > "$out/commands/router-status.md" <<'EOF'
    ---
    description: Show which backend (Ollama or Claude) the current repo uses
    allowed-tools: Bash(claude-router:*)
    ---

    !`claude-router status`
    EOF
  '';
in
{
  options.modules.programs.claude-router-cli = {
    enable = lib.mkEnableOption "claude-router CLI + apiKeyHelper for routing Claude Code between local Ollama and cloud Anthropic";

    routerHostKey = lib.mkOption {
      type = lib.types.str;
      default = "api-router-${config.networking.hostName}";
      description = ''
        Name of the agenix secret holding this host's bearer key for the
        LiteLLM router. Defaults to api-router-<hostname>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.${cfg.routerHostKey} = {
      file = ../../secrets/${cfg.routerHostKey}.age;
      mode = "0640";
      owner = "root";
      group = "users";
    };

    environment.systemPackages = [ claudeRouter claudeRouterKey ];

    environment.etc."claude-code/commands".source = "${slashCommands}/commands";

  };
}
