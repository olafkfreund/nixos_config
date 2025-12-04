{ config, lib, pkgs, ... }:

with lib;
let
  inherit (lib) types;
  cfg = config.programs.claude-code-router;

  # Use npx for now - simpler than building the package
  claude-code-router-pkg = pkgs.writeShellScriptBin "claude-code-router" ''
    exec ${pkgs.nodejs}/bin/npx --yes @musistudio/claude-code-router@1.0.66 "$@"
  '';

  # Generate router configuration
  routerConfig = {
    Router = cfg.routing;
    Providers = cfg.providers;
    inherit (cfg) transformers;
    inherit (cfg) longContextThreshold;
  };

  configFile = pkgs.writeText "claude-code-router-config.json" (builtins.toJSON routerConfig);

in
{
  options.programs.claude-code-router = {
    enable = mkEnableOption "Claude Code Router";

    package = mkOption {
      type = types.package;
      default = claude-code-router-pkg;
      description = "The claude-code-router package to use";
    };

    providers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          url = mkOption {
            type = types.str;
            description = "Provider API URL";
            example = "https://api.openai.com/v1";
          };

          apiKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "API key for the provider (use apiKeyFile for secrets)";
          };

          apiKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing API key";
            example = "/run/agenix/api-openrouter";
          };

          models = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of available models for this provider";
            example = [ "gpt-4" "gpt-3.5-turbo" ];
          };
        };
      });
      default = { };
      description = "AI provider configurations";
      example = {
        openrouter = {
          url = "https://openrouter.ai/api/v1";
          apiKeyFile = "/run/agenix/api-openrouter";
          models = [ "anthropic/claude-3.5-sonnet" "openai/gpt-4" ];
        };
      };
    };

    routing = mkOption {
      type = types.submodule {
        options = {
          default = mkOption {
            type = types.str;
            description = "Default model for general tasks";
            example = "openrouter:anthropic/claude-3.5-sonnet";
          };

          background = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Model for background tasks (cost optimization)";
            example = "ollama:mistral";
          };

          think = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Model for reasoning-heavy tasks";
            example = "openrouter:anthropic/claude-3-opus";
          };

          longContext = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Model for large context tasks";
            example = "openrouter:anthropic/claude-3.5-sonnet";
          };

          webSearch = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Model for web search tasks";
            example = "openrouter:perplexity/sonar-pro";
          };

          image = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Model for image processing tasks (beta)";
            example = "openrouter:openai/gpt-4-vision";
          };
        };
      };
      description = "Model routing configuration";
    };

    transformers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of transformers to apply to requests/responses";
      example = [ "deepseek" "gemini" "reasoning" ];
    };

    longContextThreshold = mkOption {
      type = types.int;
      default = 60000;
      description = "Token threshold for long context routing";
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        ccr = "claude-code-router";
        claude-router = "claude-code-router";
      };
      description = "Shell aliases for claude-code-router";
    };

    enableStatusLine = mkOption {
      type = types.bool;
      default = true;
      description = "Enable built-in status line for runtime monitoring";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Create configuration directory and file
    xdg.configFile."claude-code-router/config.json" = {
      source = configFile;
    };

    # Set up environment variables
    home.sessionVariables = mkMerge [
      (mkIf cfg.enableStatusLine {
        CLAUDE_CODE_ROUTER_STATUS_LINE = "1";
      })
      # Add API keys from files as environment variables
      (
        let
          providerEnvVars = mapAttrs'
            (name: provider:
              nameValuePair "CLAUDE_ROUTER_${toUpper name}_API_KEY"
                (mkIf (provider.apiKeyFile != null) "$(cat ${provider.apiKeyFile})")
            )
            cfg.providers;
        in
        providerEnvVars
      )
    ];

    # Shell aliases
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable cfg.shellAliases;
    programs.bash.shellAliases = mkIf config.programs.bash.enable cfg.shellAliases;
    programs.fish.shellAliases = mkIf config.programs.fish.enable cfg.shellAliases;

    # Integration helper script
    home.file.".local/bin/ccr-status" = {
      text = ''
        #!/usr/bin/env bash
        # Claude Code Router status and management script

        CONFIG_FILE="$HOME/.config/claude-code-router/config.json"

        show_config() {
          echo "Claude Code Router Configuration:"
          echo "================================="
          if [ -f "$CONFIG_FILE" ]; then
            ${pkgs.jq}/bin/jq '.' "$CONFIG_FILE"
          else
            echo "No configuration file found at $CONFIG_FILE"
          fi
        }

        show_providers() {
          echo "Configured Providers:"
          echo "===================="
          if [ -f "$CONFIG_FILE" ]; then
            ${pkgs.jq}/bin/jq -r '.Providers | keys[]' "$CONFIG_FILE"
          fi
        }

        show_routing() {
          echo "Model Routing:"
          echo "=============="
          if [ -f "$CONFIG_FILE" ]; then
            ${pkgs.jq}/bin/jq '.Router' "$CONFIG_FILE"
          fi
        }

        case "''${1:-help}" in
          config)
            show_config
            ;;
          providers)
            show_providers
            ;;
          routing)
            show_routing
            ;;
          help)
            echo "Usage: ccr-status <command>"
            echo "Commands:"
            echo "  config    - Show full configuration"
            echo "  providers - List configured providers"
            echo "  routing   - Show model routing rules"
            echo "  help      - Show this help"
            ;;
          *)
            echo "Unknown command: $1"
            echo "Run 'ccr-status help' for usage information"
            exit 1
            ;;
        esac
      '';
      executable = true;
    };

    # Development environment integration
    home.sessionPath = [ "$HOME/.local/bin" ];
  };
}
