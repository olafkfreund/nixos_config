{ config, pkgs, ... }:

{
  imports = [ ./codex-cli/module.nix ];

  programs.codex-cli = {
    enable = true;

    # Configuration settings
    defaultModel = "gpt-4";
    temperature = 0.1; # Lower temperature for more deterministic code generation
    maxTokens = 4096; # Increased for longer code responses
    timeout = 60; # Longer timeout for complex requests

    # Feature settings
    autoSave = true;
    syntaxHighlighting = true;
    interactiveMode = true;

    # API key integration (use agenix secret)
    apiKeyFile = "/run/agenix/api-openai";

    # Enhanced shell aliases for convenience
    shellAliases = {
      codex = "codex-cli";
      ai-code = "codex-cli";
      openai-codex = "codex-cli";
      cx = "codex-cli"; # Short alias
      code-ai = "codex-cli";

      # Project-specific aliases
      codex-project = "codex-project";
      cx-project = "codex-project";
      cx-analyze = "codex-project analyze";
      cx-ask = "codex-project ask";
    };

    # Additional configuration
    extraConfig = {
      # Editor integration
      editor = "nvim";

      # Project features
      project_templates = true;
      git_integration = true;

      # Code analysis
      static_analysis = true;
      security_scan = true;

      # Output preferences
      color_output = true;
      verbose_logging = false;

      # Performance settings
      cache_responses = true;
      parallel_requests = false;
    };
  };

  # Additional packages that work well with Codex
  home.packages = with pkgs; [
    # Code formatting and linting tools that complement AI code generation
    nodePackages.prettier
    nodePackages.eslint
    black # Python formatter
    rustfmt # Rust formatter
    nixpkgs-fmt # Nix formatter

    # Development utilities
    jq # JSON processing for API responses
    curl # API testing
    httpie # User-friendly HTTP client
  ];

  # Environment variables for enhanced integration
  home.sessionVariables = {
    # Codex-specific environment
    CODEX_CONFIG_DIR = "${config.xdg.configHome}/codex";
    CODEX_CACHE_DIR = "${config.xdg.cacheHome}/codex";

    # Integration with other tools
    CODEX_EDITOR = "nvim";
    CODEX_PROJECT_ROOT = "$(git rev-parse --show-toplevel 2>/dev/null || pwd)";
  };

  # XDG configuration for proper file organization
  xdg.configFile."codex/prompts/system.txt" = {
    text = ''
      You are an expert software engineer assistant integrated into a NixOS development environment.

      Context:
      - Operating System: NixOS (declarative Linux distribution)
      - Development setup: Comprehensive development environment with multiple languages
      - Editor: Neovim with LazyVim configuration
      - Shell: Zsh with advanced configuration
      - Package Management: Nix with flakes

      When generating code:
      1. Follow the established patterns in the project
      2. Consider NixOS-specific requirements when applicable
      3. Use modern, idiomatic code practices
      4. Include appropriate error handling
      5. Add helpful comments for complex logic
      6. Consider security implications

      Available languages and tools in this environment:
      - Nix (primary configuration language)
      - Python, Node.js, Go, Rust, Java, C/C++
      - Shell scripting (bash, zsh)
      - Configuration formats (YAML, JSON, TOML)

      Please provide clear, production-ready code with explanations.
    '';
  };

  # Create helpful scripts and integrations
  xdg.configFile."codex/templates/nix-module.nix" = {
    text = ''
      { config, lib, pkgs, ... }:

      with lib;

      let
        cfg = config.services.SERVICENAME;
      in {
        options.services.SERVICENAME = {
          enable = mkEnableOption "SERVICENAME";

          # Add your options here
        };

        config = mkIf cfg.enable {
          # Add your configuration here
        };
      }
    '';
  };

  xdg.configFile."codex/templates/python-project.py" = {
    text = ''
      #!/usr/bin/env python3
      """
      Module docstring describing the purpose of this module.
      """

      import logging
      from typing import Optional, Dict, Any

      # Configure logging
      logging.basicConfig(level=logging.INFO)
      logger = logging.getLogger(__name__)


      def main() -> None:
          """Main entry point."""
          logger.info("Starting application...")
          # Add your code here


      if __name__ == "__main__":
          main()
    '';
  };
}
