# API Keys Management with Age Encryption
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.secrets.apiKeys;

  # Get the main user from host variables  
  vars = import ../../hosts/${config.networking.hostName}/variables.nix;
  username = vars.username;
in
{
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
        mode = "0644";
        owner = "root";
        group = "users";
      };

      api-gemini = {
        file = ../../secrets/api-gemini.age;
        mode = "0644";
        owner = "root";
        group = "users";
      };

      api-anthropic = {
        file = ../../secrets/api-anthropic.age;
        mode = "0644";
        owner = "root";
        group = "users";
      };

      api-qwen = {
        file = ../../secrets/api-qwen.age;
        mode = "0644";
        owner = "root";
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

      tailscale-auth-key = {
        file = ../../secrets/tailscale-auth-key.age;
        mode = "0600";
        owner = "root";
        group = "root";
      };
    };

    # Note: System environment variables removed - use shell initialization instead
    # The load-api-keys script properly handles dynamic loading of API keys

    # Create utility scripts for API key management
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
        
        if [ -r "${config.age.secrets.api-qwen.path}" ]; then
          export QWEN_API_KEY="$(cat ${config.age.secrets.api-qwen.path})"
        fi
        
        if [ -r "${config.age.secrets.api-langchain.path}" ]; then
          export LANGCHAIN_API_KEY="$(cat ${config.age.secrets.api-langchain.path})"
        fi
        
        if [ -r "${config.age.secrets.api-github-token.path}" ]; then
          export GITHUB_TOKEN="$(cat ${config.age.secrets.api-github-token.path})"
        fi
      '')

      (pkgs.writeScriptBin "api-keys-status" ''
        #!/bin/bash
        echo "API Keys Status:"
        echo "==============="
        
        # Check environment variables
        [ -n "$OPENAI_API_KEY" ] && echo "✅ OpenAI: Available" || echo "❌ OpenAI: Not available"
        [ -n "$GEMINI_API_KEY" ] && echo "✅ Gemini: Available" || echo "❌ Gemini: Not available" 
        [ -n "$ANTHROPIC_API_KEY" ] && echo "✅ Anthropic: Available" || echo "❌ Anthropic: Not available"
        [ -n "$QWEN_API_KEY" ] && echo "✅ Qwen: Available" || echo "❌ Qwen: Not available"
        [ -n "$LANGCHAIN_API_KEY" ] && echo "✅ LangChain: Available" || echo "❌ LangChain: Not available"
        [ -n "$GITHUB_TOKEN" ] && echo "✅ GitHub Token: Available" || echo "❌ GitHub Token: Not available"
        
        echo ""
        echo "Secret Files:"
        echo "============="
        
        # Check secret files
        find /run/agenix* -name "api-*" 2>/dev/null | while read file; do
          if [ -r "$file" ] && [ -s "$file" ]; then
            basename=$(basename "$file")
            echo "✅ $basename: $file"
          fi
        done
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
        if [ -f "${config.age.secrets.api-qwen.path}" ]; then
          chown ${username}:users "${config.age.secrets.api-qwen.path}" 2>/dev/null || true
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
  };
}
