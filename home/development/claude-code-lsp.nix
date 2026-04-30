{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.programs.claudeCode.lsp;

  # Init-template content for ~/.claude/settings.json. Written ONCE on
  # activation if the file is missing; never overwritten thereafter so
  # `claude plugin install`, permission prompts, and other runtime
  # mutations stick. The PARR hook used to live here too — it now lives
  # in /etc/claude-code/managed-settings.json (managed scope) so users
  # cannot disable it by editing this file. See issue #398.
  userSettingsTemplate = pkgs.writeText "claude-user-settings.json"
    (builtins.toJSON (
      {
        statusLine = {
          type = "command";
          command = "${config.home.homeDirectory}/.claude/statusline-gruvbox.sh";
        };
      }
      // lib.optionalAttrs cfg.enableNixLsp {
        enabledPlugins = {
          "nix-lsp@nixos-lsp-marketplace" = true;
        };
      }
    ));

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
  options.programs.claudeCode = {
    lsp = {
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

    # NOTE: programs.claudeCode.hooks.enableParrProtocol was removed in
    # issue #398. The PARR hook moved to managed scope; configure via
    # modules.programs.claude-code-managed.parrProtocol.enable in your
    # NixOS configuration.
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

          # NOTE: ~/.claude/settings.json is NOT a home.file anymore.
          # Claude Code mutates it at runtime (`claude plugin install`,
          # permission prompts, statusline UI) so a nix-store symlink would
          # break with EACCES. See issue #398 and the activation script
          # claudeUserSettingsInit below for the init-template pattern.
        };

        activation = {
          # Seed ~/.claude/settings.json from a Nix-rendered template ONLY
          # if the file doesn't already exist as a regular (non-symlink)
          # file. This makes the user-scope settings file writable so
          # Claude Code can mutate it at runtime, while still giving us
          # declarative defaults on a fresh setup.
          #
          # Migration handling: if the file is a symlink (e.g. legacy
          # nix-store symlink from before #398), unlink it first and seed
          # the template. Existing user-edited content (regular file) is
          # preserved untouched.
          claudeUserSettingsInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            target="$HOME/.claude/settings.json"
            mkdir -p "$HOME/.claude"

            if [ -L "$target" ]; then
              # Legacy symlink (likely into /nix/store) — remove it so we
              # can write a real file. The pre-existing target was always
              # the same Nix-rendered content, nothing user-authored is
              # lost.
              $DRY_RUN_CMD rm -f "$target"
            fi

            if [ ! -e "$target" ]; then
              $DRY_RUN_CMD install -m 0644 ${userSettingsTemplate} "$target"
              $DRY_RUN_CMD echo "Seeded $target from Nix template"
            fi
          '';

          # Install Claude Code's nix-lsp plugin on first activation. Now
          # that ~/.claude/settings.json is writable (see #398), this can
          # actually succeed; it used to silently fail with EACCES, hidden
          # by the 2>/dev/null swallow. Errors now surface to the user
          # except for the "claude not installed yet" path, which is
          # legitimately optional.
          #
          # Runs after claudeUserSettingsInit so the settings file exists
          # before `claude plugin install` tries to write to it.
          claudeCodeLspSetup = lib.hm.dag.entryAfter [ "claudeUserSettingsInit" ] ''
            if ! command -v claude >/dev/null 2>&1; then
              $DRY_RUN_CMD echo "Claude Code not found, skipping LSP setup"
              exit 0
            fi

            $DRY_RUN_CMD echo "Setting up Claude Code LSP plugins..."

            marketplace_exists() {
              claude plugin marketplace list | grep -q "nixos-lsp-marketplace"
            }

            plugin_installed() {
              claude plugin marketplace list | grep -q "nix-lsp@nixos-lsp-marketplace" \
                || ( [ -f "$HOME/.claude/plugins/installed_plugins.json" ] \
                     && grep -q "nix-lsp@nixos-lsp-marketplace" "$HOME/.claude/plugins/installed_plugins.json" )
            }

            if ! marketplace_exists; then
              $DRY_RUN_CMD echo "Adding nixos-lsp-marketplace..."
              $DRY_RUN_CMD claude plugin marketplace add "${cfg.customMarketplacePath}"
            fi

            if ! plugin_installed; then
              $DRY_RUN_CMD echo "Installing nix-lsp plugin..."
              $DRY_RUN_CMD claude plugin install nix-lsp@nixos-lsp-marketplace
            fi

            $DRY_RUN_CMD echo "Claude Code LSP setup complete!"
          '';

          # MCP server configuration is now handled by claude-code-mcp.nix module
          # The module generates ~/.claude/settings.local.json automatically
          # This provides Nix-based conditional MCP server configuration
        };
      };
    })
  ];
}
