{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.programs.claudeCode.lsp;

  # Marketplace configuration for Nix LSP
  marketplaceJson = pkgs.writeTextFile {
    name = "nix-lsp-marketplace.json";
    text = builtins.toJSON {
      "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
      name = "nixos-lsp-marketplace";
      description = "NixOS Language Server Protocol plugins for Claude Code";
      owner = {
        name = "NixOS User";
        email = "local@localhost";
      };
      plugins = [
        {
          name = "nix-lsp";
          description = "Nix language server (nil) for enhanced code intelligence in Nix expressions";
          version = "1.0.0";
          author = {
            name = "NixOS User";
            email = "local@localhost";
          };
          source = "./plugins/nix-lsp";
          category = "development";
          strict = false;
          lspServers = {
            nil = {
              command = "nil";
              args = [ ];
              extensionToLanguage = {
                ".nix" = "nix";
              };
            };
          };
        }
      ];
    };
  };

  # Plugin README
  pluginReadme = pkgs.writeTextFile {
    name = "nix-lsp-readme.md";
    text = ''
      # nix-lsp

      Nix language servers (nil and nixd) for Claude Code, providing static analysis and code intelligence for Nix expressions.

      ## Supported Extensions
      `.nix`

      ## Installation

      The language servers are already installed via NixOS and available in your PATH:

      - **nil**: Modern, fast Nix LSP server with excellent performance
      - **nixd**: Feature-rich Nix LSP server with advanced nixpkgs integration

      Both servers are configured in `~/.config/lsp-servers/config.json` with proper file type associations and root patterns.

      ## LSP Features

      - Code completion for Nix expressions
      - Hover documentation for built-in functions
      - Go to definition for variables and functions
      - Find references across Nix files
      - Diagnostics for syntax and semantic errors
      - Code formatting with nixpkgs-fmt

      ## More Information
      - [nil LSP Server](https://github.com/oxalica/nil) - Fast and modern
      - [nixd LSP Server](https://github.com/nix-community/nixd) - Advanced features
      - [NixOS Manual](https://nixos.org/manual/nixos/stable/)
    '';
  };
in
{
  options.programs.claudeCode.lsp = {
    enable = mkEnableOption "Claude Code LSP plugin configuration";

    enableNixLsp = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Nix language server support in Claude Code";
    };

    customMarketplacePath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.claude/plugins/custom-marketplace";
      description = "Path to custom Claude Code plugin marketplace";
    };
  };

  config = mkMerge [
    # Auto-enable when this module is imported
    {
      programs.claudeCode.lsp.enable = mkDefault true;
    }

    (mkIf cfg.enable {
      # Create the custom marketplace directory structure and manage settings
      home = {
        file = {
          # Marketplace configuration
          ".claude/plugins/custom-marketplace/.claude-plugin/marketplace.json".source = marketplaceJson;

          # Plugin README
          ".claude/plugins/custom-marketplace/plugins/nix-lsp/README.md".source = pluginReadme;

          # Ensure the plugin is enabled in settings.json
          # Note: This will be merged with existing settings by Home Manager
          ".claude/settings.json" = mkIf cfg.enableNixLsp {
            text = builtins.toJSON {
              enabledPlugins = {
                "nix-lsp@nixos-lsp-marketplace" = true;
              };
              # Claude Code status line with powerline theme
              statusLine = {
                type = "command";
                command = "${config.home.homeDirectory}/.claude/statusline-powerline.sh";
              };
            };
            onChange = ''
              # Merge with existing settings if they exist
              if [ -f "$HOME/.claude/settings.json.backup" ]; then
                ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
                  "$HOME/.claude/settings.json.backup" \
                  "$HOME/.claude/settings.json" \
                  > "$HOME/.claude/settings.json.tmp" && \
                mv "$HOME/.claude/settings.json.tmp" "$HOME/.claude/settings.json"
              fi
            '';
          };
        };

        activation = {
          # Add shell command to install the marketplace and plugin on first activation
          # This uses a script that only runs if the marketplace isn't already installed
          claudeCodeLspSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            # Check if Claude Code is available
            if command -v claude &>/dev/null; then
              $DRY_RUN_CMD echo "Setting up Claude Code LSP plugins..."

              # Function to check if marketplace exists
              marketplace_exists() {
                claude plugin marketplace list 2>/dev/null | grep -q "nixos-lsp-marketplace"
              }

              # Function to check if plugin is installed
              plugin_installed() {
                claude plugin marketplace list 2>/dev/null | grep -q "nix-lsp@nixos-lsp-marketplace" || \
                [ -f "$HOME/.claude/plugins/installed_plugins.json" ] && \
                grep -q "nix-lsp@nixos-lsp-marketplace" "$HOME/.claude/plugins/installed_plugins.json"
              }

              # Add marketplace if it doesn't exist
              if ! marketplace_exists; then
                $DRY_RUN_CMD echo "Adding nixos-lsp-marketplace..."
                $DRY_RUN_CMD claude plugin marketplace add "${cfg.customMarketplacePath}" 2>/dev/null || true
              fi

              # Install plugin if not already installed
              if ! plugin_installed; then
                $DRY_RUN_CMD echo "Installing nix-lsp plugin..."
                $DRY_RUN_CMD claude plugin install nix-lsp@nixos-lsp-marketplace 2>/dev/null || true
              fi

              $DRY_RUN_CMD echo "Claude Code LSP setup complete!"
            else
              $DRY_RUN_CMD echo "Claude Code not found, skipping LSP setup"
            fi
          '';

          # MCP server configuration is now handled by claude-code-mcp.nix module
          # The module generates ~/.claude/settings.local.json automatically
          # This provides Nix-based conditional MCP server configuration
        };
      };
    })
  ];
}
