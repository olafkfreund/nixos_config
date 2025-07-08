{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ai.providers;
  
  # Create the unified AI CLI script
  unifiedAiScript = pkgs.writeShellScriptBin "ai-cli" ''
    #!/bin/bash
    
    # AI CLI - Unified interface for multiple LLM providers
    # Usage: ai-cli [options] "prompt"
    
    set -euo pipefail
    
    # Default configuration
    CONFIG_FILE="''${AI_PROVIDERS_CONFIG:-/etc/ai-providers.json}"
    DEFAULT_PROVIDER="''${AI_DEFAULT_PROVIDER:-${cfg.defaultProvider}}"
    VERBOSE=false
    FALLBACK=false
    COST_OPTIMIZE=false
    PROVIDER=""
    MODEL=""
    TIMEOUT=30
    
    # Help function
    show_help() {
        cat << EOF
    AI CLI - Unified LLM Provider Interface
    
    Usage: ai-cli [OPTIONS] "prompt"
    
    OPTIONS:
        -p, --provider PROVIDER    Use specific provider (openai|anthropic|gemini|ollama)
        -m, --model MODEL         Use specific model
        -f, --fallback            Enable fallback to other providers on failure
        -c, --cost-optimize       Use cost optimization for provider selection
        -t, --timeout SECONDS     Request timeout (default: 30)
        -v, --verbose             Verbose output
        -l, --list-providers      List available providers
        -M, --list-models         List available models for provider
        -s, --status              Show provider status
        -h, --help                Show this help
    
    EXAMPLES:
        ai-cli "Hello, world!"
        ai-cli -p anthropic "Explain quantum computing"
        ai-cli -m gpt-4o "Write a Python function"
        ai-cli -f -c "Complex analysis task"
        ai-cli -l
        ai-cli -p ollama -M
    
    ENVIRONMENT:
        AI_PROVIDERS_CONFIG       Path to providers config file
        AI_DEFAULT_PROVIDER       Default provider to use
    EOF
    }
    
    # Logging functions
    log_info() { [[ "$VERBOSE" == "true" ]] && echo "INFO: $*" >&2; }
    log_error() { echo "ERROR: $*" >&2; }
    log_warn() { echo "WARN: $*" >&2; }
    
    # Load configuration
    load_config() {
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "Configuration file not found: $CONFIG_FILE"
            exit 1
        fi
        
        if ! command -v jq >/dev/null 2>&1; then
            log_error "jq is required but not installed"
            exit 1
        fi
    }
    
    # Get provider information
    get_provider_info() {
        local provider="$1"
        jq -r ".providers.$provider // empty" "$CONFIG_FILE"
    }
    
    # Check if provider is enabled
    is_provider_enabled() {
        local provider="$1"
        local enabled=$(jq -r ".providers.$provider.enabled // false" "$CONFIG_FILE")
        [[ "$enabled" == "true" ]]
    }
    
    # Get sorted providers by priority
    get_providers_by_priority() {
        jq -r '.providers | to_entries | map(select(.value.enabled == true)) | sort_by(.value.priority) | .[].key' "$CONFIG_FILE"
    }
    
    # List providers
    list_providers() {
        echo "Available providers:"
        echo "==================="
        
        while IFS= read -r provider; do
            local info=$(get_provider_info "$provider")
            local priority=$(echo "$info" | jq -r '.priority')
            local defaultModel=$(echo "$info" | jq -r '.defaultModel')
            local status="✓"
            
            # Check if API key exists for providers that need it
            local requiresApiKey=$(echo "$info" | jq -r '.requiresApiKey // true')
            if [[ "$requiresApiKey" == "true" ]]; then
                local apiKeyFile=$(echo "$info" | jq -r '.apiKeyFile')
                if [[ ! -f "$apiKeyFile" ]]; then
                    status="✗ (missing API key)"
                fi
            fi
            
            printf "%-12s Priority: %d, Model: %-25s %s\n" "$provider" "$priority" "$defaultModel" "$status"
        done < <(get_providers_by_priority)
    }
    
    # List models for a provider
    list_models() {
        local provider="$1"
        if ! is_provider_enabled "$provider"; then
            log_error "Provider '$provider' is not enabled"
            exit 1
        fi
        
        echo "Available models for $provider:"
        echo "==============================="
        
        local models=$(jq -r ".providers.$provider.models[]" "$CONFIG_FILE")
        local defaultModel=$(jq -r ".providers.$provider.defaultModel" "$CONFIG_FILE")
        
        while IFS= read -r model; do
            local marker=""
            [[ "$model" == "$defaultModel" ]] && marker=" (default)"
            echo "  $model$marker"
        done <<< "$models"
    }
    
    # Show provider status
    show_status() {
        echo "AI Provider Status"
        echo "=================="
        echo "Default provider: $DEFAULT_PROVIDER"
        echo "Config file: $CONFIG_FILE"
        echo ""
        
        list_providers
        
        echo ""
        echo "System Status:"
        echo "=============="
        
        # Check Ollama if enabled
        if is_provider_enabled "ollama"; then
            if systemctl is-active ollama >/dev/null 2>&1; then
                echo "Ollama service: Running"
            else
                echo "Ollama service: Stopped"
            fi
        fi
        
        # Check API keys
        echo ""
        echo "API Keys:"
        for provider in openai anthropic gemini; do
            if is_provider_enabled "$provider"; then
                local keyFile=$(jq -r ".providers.$provider.apiKeyFile" "$CONFIG_FILE")
                if [[ -f "$keyFile" ]]; then
                    echo "  $provider: ✓"
                else
                    echo "  $provider: ✗"
                fi
            fi
        done
    }
    
    # Make API request
    make_request() {
        local provider="$1"
        local model="$2"
        local prompt="$3"
        
        log_info "Using provider: $provider, model: $model"
        
        case "$provider" in
            "openai")
                if [[ -f "/run/agenix/api-openai" ]]; then
                    export OPENAI_API_KEY="$(cat /run/agenix/api-openai)"
                    if command -v chatgpt-cli >/dev/null 2>&1; then
                        timeout "$TIMEOUT" chatgpt-cli -m "$model" "$prompt"
                    else
                        log_error "OpenAI CLI tools not available"
                        return 1
                    fi
                else
                    log_error "OpenAI API key not found"
                    return 1
                fi
                ;;
            "anthropic")
                if [[ -f "/run/agenix/api-anthropic" ]]; then
                    export ANTHROPIC_API_KEY="$(cat /run/agenix/api-anthropic)"
                    if command -v aichat >/dev/null 2>&1; then
                        timeout "$TIMEOUT" aichat --model "claude:$model" "$prompt"
                    else
                        log_error "Claude CLI tools not available"
                        return 1
                    fi
                else
                    log_error "Anthropic API key not found"
                    return 1
                fi
                ;;
            "gemini")
                if [[ -f "/run/agenix/api-gemini" ]]; then
                    export GEMINI_API_KEY="$(cat /run/agenix/api-gemini)"
                    if command -v gemini-cli >/dev/null 2>&1; then
                        timeout "$TIMEOUT" gemini-cli --model "$model" "$prompt"
                    elif command -v aichat >/dev/null 2>&1; then
                        timeout "$TIMEOUT" aichat --model "gemini:$model" "$prompt"
                    else
                        log_error "Gemini CLI tools not available"
                        return 1
                    fi
                else
                    log_error "Gemini API key not found"
                    return 1
                fi
                ;;
            "ollama")
                if command -v ollama >/dev/null 2>&1; then
                    if ollama list >/dev/null 2>&1; then
                        timeout "$TIMEOUT" ollama run "$model" "$prompt"
                    else
                        log_error "Ollama service not running"
                        return 1
                    fi
                else
                    log_error "Ollama not available"
                    return 1
                fi
                ;;
            *)
                log_error "Unknown provider: $provider"
                return 1
                ;;
        esac
    }
    
    # Process request with fallback
    process_request() {
        local prompt="$1"
        local providers=()
        local max_retries=$(jq -r '.maxRetries // 3' "$CONFIG_FILE")
        
        if [[ -n "$PROVIDER" ]]; then
            if is_provider_enabled "$PROVIDER"; then
                providers=("$PROVIDER")
            else
                log_error "Provider '$PROVIDER' is not enabled"
                exit 1
            fi
        else
            # Use all enabled providers by priority
            while IFS= read -r provider; do
                providers+=("$provider")
            done < <(get_providers_by_priority)
        fi
        
        for provider in "''${providers[@]}"; do
            local provider_model="$MODEL"
            if [[ -z "$provider_model" ]]; then
                provider_model=$(jq -r ".providers.$provider.defaultModel" "$CONFIG_FILE")
            fi
            
            log_info "Trying provider: $provider with model: $provider_model"
            
            local retry=0
            while [[ $retry -lt $max_retries ]]; do
                if make_request "$provider" "$provider_model" "$prompt"; then
                    log_info "Success with provider: $provider"
                    return 0
                fi
                
                ((retry++))
                log_warn "Attempt $retry failed for provider: $provider"
                
                if [[ $retry -lt $max_retries ]]; then
                    log_info "Retrying in 2 seconds..."
                    sleep 2
                fi
            done
            
            log_warn "Provider $provider failed after $max_retries attempts"
            
            if [[ "$FALLBACK" != "true" ]]; then
                log_error "Fallback disabled, stopping"
                exit 1
            fi
            
            log_info "Trying next provider..."
        done
        
        log_error "All providers failed"
        exit 1
    }
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--provider)
                PROVIDER="$2"
                shift 2
                ;;
            -m|--model)
                MODEL="$2"
                shift 2
                ;;
            -f|--fallback)
                FALLBACK=true
                shift
                ;;
            -c|--cost-optimize)
                COST_OPTIMIZE=true
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -l|--list-providers)
                load_config
                list_providers
                exit 0
                ;;
            -M|--list-models)
                load_config
                if [[ -z "$PROVIDER" ]]; then
                    log_error "Provider required for listing models. Use -p <provider>"
                    exit 1
                fi
                list_models "$PROVIDER"
                exit 0
                ;;
            -s|--status)
                load_config
                show_status
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # This is the prompt
                PROMPT="$1"
                shift
                ;;
        esac
    done
    
    # Check if prompt was provided
    if [[ -z "''${PROMPT:-}" ]]; then
        log_error "No prompt provided"
        show_help
        exit 1
    fi
    
    # Load configuration and process request
    load_config
    process_request "$PROMPT"
  '';

  # Create provider switching script
  providerSwitchScript = pkgs.writeShellScriptBin "ai-switch" ''
    #!/bin/bash
    
    # AI Provider Switcher
    # Usage: ai-switch [provider]
    
    CONFIG_FILE="''${AI_PROVIDERS_CONFIG:-/etc/ai-providers.json}"
    
    show_help() {
        cat << EOF
    AI Provider Switcher
    
    Usage: ai-switch [provider]
    
    Available providers: openai, anthropic, gemini, ollama
    
    Examples:
        ai-switch openai     # Switch to OpenAI
        ai-switch            # Show current provider
    EOF
    }
    
    if [[ $# -eq 0 ]]; then
        echo "Current default provider: ''${AI_DEFAULT_PROVIDER:-unknown}"
        exit 0
    fi
    
    provider="$1"
    
    case "$provider" in
        openai|anthropic|gemini|ollama)
            export AI_DEFAULT_PROVIDER="$provider"
            echo "Switched to provider: $provider"
            echo "This change is only for the current session."
            echo "To make it permanent, update your configuration."
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown provider: $provider"
            show_help
            exit 1
            ;;
    esac
  '';

in {
  options.ai.providers.unifiedClient = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable unified AI client";
    };
  };

  config = mkIf (cfg.enable && cfg.unifiedClient.enable) {
    environment.systemPackages = [
      unifiedAiScript
      providerSwitchScript
      pkgs.jq # Required for JSON parsing
      # Add ai-chat as an alias to ai-cli for user convenience
      (pkgs.writeShellScriptBin "ai-chat" ''
        exec ${unifiedAiScript}/bin/ai-cli "$@"
      '')
    ];

    # Enhanced shell integration
    programs.zsh.interactiveShellInit = mkAfter ''
      # Unified AI client functions
      ai() {
        ai-cli "$@"
      }
      
      # Chat alias for convenience 
      chat() {
        ai-cli "$@"
      }
      
      # Quick provider-specific aliases
      ai-quick() {
        local provider="''${AI_DEFAULT_PROVIDER:-${cfg.defaultProvider}}"
        ai-cli -p "$provider" "$@"
      }
      
      ai-fallback() {
        ai-cli --fallback "$@"
      }
      
      ai-cost() {
        ai-cli --cost-optimize --fallback "$@"
      }
      
      # Provider management
      ai-providers() {
        ai-cli --list-providers
      }
      
      ai-models() {
        local provider="''${1:-''${AI_DEFAULT_PROVIDER:-${cfg.defaultProvider}}}"
        ai-cli -p "$provider" --list-models
      }
      
      ai-status() {
        ai-cli --status
      }
      
      # Aliases for convenience
      alias aii='ai-quick'
      alias aif='ai-fallback'
      alias aic='ai-cost'
    '';
  };
}