# Development Tool Module Template
#
# This template is for development tools, programming languages,
# and development environment configurations.
#
# Usage:
# 1. Copy to modules/development/TOOL_NAME.nix
# 2. Replace PLACEHOLDER values
# 3. Add to modules/development/default.nix imports
# 4. Enable with: features.development.TOOL_NAME = true;
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.development.TOOL_NAME;
in
{
  options.modules.development.TOOL_NAME = {
    enable = mkEnableOption "TOOL_NAME development environment";

    # Package selection
    package = mkOption {
      type = types.package;
      default = pkgs.TOOL_PACKAGE;
      description = "The TOOL_NAME package to use";
    };

    # Additional packages
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional TOOL_NAME-related packages";
      example = literalExpression "[ pkgs.tool-extension pkgs.tool-plugin ]";
    };

    # Language/Tool specific options
    version = mkOption {
      type = types.str;
      default = "latest";
      description = "TOOL_NAME version to use";
      example = "1.0.0";
    };

    # Development features
    enableLSP = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Language Server Protocol support";
    };

    enableDebugger = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debugger support";
    };

    enableFormatter = mkOption {
      type = types.bool;
      default = true;
      description = "Enable code formatter";
    };

    enableLinter = mkOption {
      type = types.bool;
      default = true;
      description = "Enable code linter";
    };

    # Configuration settings
    globalConfig = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Global TOOL_NAME configuration";
      example = literalExpression ''
        {
          "setting1" = "value1";
          "setting2" = "value2";
        }
      '';
    };

    # Project templates
    enableProjectTemplates = mkOption {
      type = types.bool;
      default = false;
      description = "Install project templates and scaffolding tools";
    };

    # Shell integration
    enableShellIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable shell integration (completions, aliases)";
    };

    # Editor integration
    enableEditorIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable editor integration and plugins";
    };
  };

  config = mkIf cfg.enable {
    # Core packages
    environment.systemPackages = with pkgs;
      [
        cfg.package
      ]
      # Language Server Protocol
      ++ optionals cfg.enableLSP [
        # TOOL_NAME-lsp
      ]
      # Debugger support
      ++ optionals cfg.enableDebugger [
        # TOOL_NAME-debugger
      ]
      # Formatter
      ++ optionals cfg.enableFormatter [
        # TOOL_NAME-formatter
      ]
      # Linter
      ++ optionals cfg.enableLinter [
        # TOOL_NAME-linter
      ]
      # Project templates
      ++ optionals cfg.enableProjectTemplates [
        # TOOL_NAME-templates
        # cookiecutter
      ]
      # Additional packages
      ++ cfg.extraPackages;

    # Environment variables
    environment.variables =
      {
        # TOOL_NAME_HOME = "/etc/TOOL_NAME";
        # TOOL_NAME_CONFIG = "/etc/TOOL_NAME/config";
      }
      // cfg.globalConfig;

    # Shell aliases and functions
    environment.shellAliases = mkIf cfg.enableShellIntegration {
      # Common TOOL_NAME aliases
      # TOOL_alias = "TOOL_NAME command";
    };

    # Global configuration file
    environment.etc."TOOL_NAME/config" = mkIf (cfg.globalConfig != { }) {
      text = concatStringsSep "\n" (mapAttrsToList (name: value: "${name}=${value}") cfg.globalConfig);
      mode = "0644";
    };

    # Development environment setup
    programs.TOOL_NAME = mkIf (hasAttr "TOOL_NAME" config.programs) {
      enable = true;
      package = cfg.package;

      # Tool-specific configuration
      # settings = cfg.globalConfig;
    };

    # Editor integration (for VS Code, Neovim, etc.)
    # programs.vscode = mkIf (cfg.enableEditorIntegration && config.programs.vscode.enable) {
    #   extensions = with pkgs.vscode-extensions; [
    #     # TOOL_NAME-extension
    #   ];
    # };

    # Shell completion
    programs.bash.completion.enable = mkIf cfg.enableShellIntegration true;
    programs.zsh.completion.enable = mkIf cfg.enableShellIntegration true;
    programs.fish.completion.enable = mkIf cfg.enableShellIntegration true;

    # Development-specific systemd services (if needed)
    # systemd.user.services.TOOL_NAME-daemon = mkIf cfg.enableLSP {
    #   description = "TOOL_NAME Language Server Daemon";
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStart = "${cfg.package}/bin/TOOL_NAME-lsp";
    #     Restart = "always";
    #   };
    # };

    # Development directories and permissions
    systemd.tmpfiles.rules = [
      "d /tmp/TOOL_NAME 0755 - - 1d"
      # "d /var/cache/TOOL_NAME 0755 - - -"
    ];

    # Firewall rules for development servers (if needed)
    # networking.firewall.allowedTCPPorts = [
    #   3000  # Development server port
    #   8080  # Alternative dev port
    # ];

    # Development-specific udev rules (for hardware tools)
    # services.udev.extraRules = ''
    #   # TOOL_NAME hardware access rules
    #   SUBSYSTEM=="usb", ATTRS{idVendor}=="1234", MODE="0666"
    # '';

    # Validation assertions
    assertions = [
      {
        assertion = cfg.package != null;
        message = "TOOL_NAME package must be specified";
      }
      {
        assertion = !(cfg.enableLSP && !cfg.enableEditorIntegration);
        message = "TOOL_NAME: LSP requires editor integration to be useful";
      }
    ];

    # Development-specific warnings
    warnings = [
      (mkIf (cfg.enableDebugger && !cfg.enableLSP) ''
        TOOL_NAME: Debugger is enabled but LSP is not.
        Consider enabling LSP for better debugging experience.
      '')
      (mkIf (cfg.enableProjectTemplates && cfg.extraPackages == [ ]) ''
        TOOL_NAME: Project templates enabled but no extra packages specified.
        Consider adding relevant packages to extraPackages.
      '')
      (mkIf (!cfg.enableShellIntegration && cfg.enableEditorIntegration) ''
        TOOL_NAME: Editor integration is enabled but shell integration is not.
        Consider enabling shell integration for a complete development experience.
      '')
    ];
  };
}
