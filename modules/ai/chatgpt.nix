# AI and ChatGPT Tools Module
# Provides various AI-powered command line tools and interfaces
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.ai.chatgpt;
in
{

  options.modules.ai.chatgpt = {
    enable = mkEnableOption "AI and ChatGPT command line tools";

    packages = {
      chatInterfaces = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable chat interfaces like ChatGPT CLI, TGPT, and Shell-GPT.
          These provide direct command-line access to various AI models.
        '';
      };

      codeAssistants = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable code assistance tools like GitHub Copilot CLI and Aichat.
          These tools help with code generation and programming tasks.
        '';
      };

      terminalTools = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable terminal-based AI tools like OTerm and Gorilla CLI.
          These provide AI assistance directly in terminal workflows.
        '';
      };

      mcpTools = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable Model Context Protocol (MCP) tools for advanced AI integrations.
          These are specialized tools for AI model communication.
        '';
      };
    };

    additionalPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Additional AI-related packages to install beyond the default sets.
      '';
      example = literalExpression ''
        with pkgs; [
          anthropic-claude
          openai-cli
        ]
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      # Chat interfaces
      optionals cfg.packages.chatInterfaces [
        chatgpt-cli # OpenAI ChatGPT command line interface
        rPackages.chatgpt # R interface for ChatGPT
        tgpt # Terminal GPT - simple CLI for multiple AI models
        shell-gpt # Shell integration for GPT models
        yai
        codex # Yet Another AI CLI tool
      ] ++

      # Code assistants  
      optionals cfg.packages.codeAssistants [
        gh-copilot # GitHub Copilot CLI integration
        aichat # AI chat with code assistance features
        gpt-cli # General purpose GPT CLI
        # codex removed due to build issues with OpenSSL dependencies
      ] ++

      # Terminal tools
      optionals cfg.packages.terminalTools [
        gorilla-cli # AI-powered command suggestions
        # oterm               # AI-enhanced terminal (disabled due to textual test failures)
      ] ++

      # MCP tools (Model Context Protocol)
      optionals cfg.packages.mcpTools [
        chatmcp # ChatGPT with MCP support
        mcphost # MCP host implementation
      ] ++

      # Additional user-specified packages
      cfg.additionalPackages;

    # Configure environment for AI tools
    environment.sessionVariables = {
      # Set default AI model preferences (users can override)
      OPENAI_API_MODEL = mkDefault "gpt-4";
      # Enable shell-gpt command completion
      SHELL_GPT_COMPLETION = mkDefault "1";
    };

    # Add helpful aliases for common AI tasks
    environment.shellAliases = {
      ai = "shell-gpt"; # Higher priority than gemini-cli default
      chat = "chatgpt-cli";
      aicode = "gh copilot suggest";
      aiexplain = "gh copilot explain";
    };

    # Ensure proper permissions for AI config directories
    systemd.tmpfiles.rules = [
      "d /etc/ai-tools 0755 root root -"
    ];

    # Helpful warnings for configuration
    warnings = optional (!cfg.packages.chatInterfaces && !cfg.packages.codeAssistants && !cfg.packages.terminalTools) ''
      modules.ai.chatgpt is enabled but no package categories are selected.
      Enable at least one package category for useful functionality.
    '';

    assertions = [
      {
        assertion = cfg.packages.mcpTools -> cfg.packages.chatInterfaces;
        message = "MCP tools require chat interfaces to be enabled";
      }
    ];
  };
}
