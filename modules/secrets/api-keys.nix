# API Keys Management with Age Encryption
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.secrets.apiKeys;
  
  # Get the main user from host variables  
  vars = import ../../hosts/${config.networking.hostName}/variables.nix;
  username = vars.username;
in {
  options.secrets.apiKeys = {
    enable = mkEnableOption "Enable encrypted API keys management";
    
    enableEnvironmentVariables = mkOption {
      type = types.bool;
      default = true;
      description = "Export API keys as environment variables system-wide";
    };
    
    enableUserEnvironment = mkOption {
      type = types.bool;
      default = true;
      description = "Export API keys in user shell environment";
    };
  };

  config = mkIf cfg.enable {
    # Define age secrets for API keys
    age.secrets = {
      api-openai = {
        file = ../../secrets/api-openai.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
      
      api-gemini = {
        file = ../../secrets/api-gemini.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
      
      api-anthropic = {
        file = ../../secrets/api-anthropic.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
      
      api-langchain = {
        file = ../../secrets/api-langchain.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
      
      api-github-token = {
        file = ../../secrets/api-github-token.age;
        mode = "0600";
        owner = username;
        group = "users";
      };
    };

    # Export as system environment variables (available to all processes)
    environment.variables = mkIf cfg.enableEnvironmentVariables {
      OPENAI_API_KEY = "$(cat ${config.age.secrets.api-openai.path} 2>/dev/null || echo '')";
      OPENAI_KEY = "$(cat ${config.age.secrets.api-openai.path} 2>/dev/null || echo '')"; # Duplicate for compatibility
      GEMINI_API_KEY = "$(cat ${config.age.secrets.api-gemini.path} 2>/dev/null || echo '')";
      ANTHROPIC_API_KEY = "$(cat ${config.age.secrets.api-anthropic.path} 2>/dev/null || echo '')";
      LANGCHAIN_API_KEY = "$(cat ${config.age.secrets.api-langchain.path} 2>/dev/null || echo '')";
      GITHUB_TOKEN = "$(cat ${config.age.secrets.api-github-token.path} 2>/dev/null || echo '')";
    };

    # Create a script for loading API keys in user sessions
    environment.systemPackages = [
      (pkgs.writeScriptBin "load-api-keys" ''
        #!/bin/sh
        # Load API keys from encrypted storage
        # This script can be sourced in shell sessions
        
        if [ -r "${config.age.secrets.api-openai.path}" ]; then
          export OPENAI_API_KEY="$(cat ${config.age.secrets.api-openai.path})"
          export OPENAI_KEY="$OPENAI_API_KEY"  # Compatibility alias
        fi
        
        if [ -r "${config.age.secrets.api-gemini.path}" ]; then
          export GEMINI_API_KEY="$(cat ${config.age.secrets.api-gemini.path})"
        fi
        
        if [ -r "${config.age.secrets.api-anthropic.path}" ]; then
          export ANTHROPIC_API_KEY="$(cat ${config.age.secrets.api-anthropic.path})"
        fi
        
        if [ -r "${config.age.secrets.api-langchain.path}" ]; then
          export LANGCHAIN_API_KEY="$(cat ${config.age.secrets.api-langchain.path})"
        fi
        
        if [ -r "${config.age.secrets.api-github-token.path}" ]; then
          export GITHUB_TOKEN="$(cat ${config.age.secrets.api-github-token.path})"
        fi
        
        echo "API keys loaded successfully"
      '')
    ];

    # Add to user shell initialization (for interactive sessions)
    programs.zsh.interactiveShellInit = mkIf cfg.enableUserEnvironment ''
      # Load API keys if available
      if command -v load-api-keys >/dev/null 2>&1; then
        eval "$(load-api-keys 2>/dev/null)"
      fi
    '';

    programs.bash.interactiveShellInit = mkIf cfg.enableUserEnvironment ''
      # Load API keys if available  
      if command -v load-api-keys >/dev/null 2>&1; then
        eval "$(load-api-keys 2>/dev/null)"
      fi
    '';

    # Ensure secrets are accessible after system activation
    system.activationScripts.api-keys-setup = {
      text = ''
        # Ensure API key files are readable by the user
        if [ -f "${config.age.secrets.api-openai.path}" ]; then
          chown ${username}:users "${config.age.secrets.api-openai.path}" 2>/dev/null || true
        fi
        if [ -f "${config.age.secrets.api-gemini.path}" ]; then
          chown ${username}:users "${config.age.secrets.api-gemini.path}" 2>/dev/null || true
        fi
        if [ -f "${config.age.secrets.api-anthropic.path}" ]; then
          chown ${username}:users "${config.age.secrets.api-anthropic.path}" 2>/dev/null || true
        fi
        if [ -f "${config.age.secrets.api-langchain.path}" ]; then
          chown ${username}:users "${config.age.secrets.api-langchain.path}" 2>/dev/null || true
        fi
        if [ -f "${config.age.secrets.api-github-token.path}" ]; then
          chown ${username}:users "${config.age.secrets.api-github-token.path}" 2>/dev/null || true
        fi
      '';
      deps = [ "agenix" ];
    };
    
    # Create a status script to check which keys are available
    environment.systemPackages = [
      (pkgs.writeScriptBin "api-keys-status" ''
        #!/bin/sh
        echo "API Keys Status:"
        echo "==============="
        
        check_key() {
          local name="$1"
          local path="$2"
          if [ -r "$path" ] && [ -s "$path" ]; then
            echo "✅ $name: Available"
          else
            echo "❌ $name: Not available"
          fi
        }
        
        check_key "OpenAI" "${config.age.secrets.api-openai.path}"
        check_key "Gemini" "${config.age.secrets.api-gemini.path}"
        check_key "Anthropic" "${config.age.secrets.api-anthropic.path}"
        check_key "LangChain" "${config.age.secrets.api-langchain.path}"
        check_key "GitHub Token" "${config.age.secrets.api-github-token.path}"
      '')
    ];
  };
}