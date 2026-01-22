{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.precommit) {
    environment.systemPackages = with pkgs; [
      # Pre-commit framework
      pre-commit

      # Nix formatting and linting tools
      nixpkgs-fmt
      statix
      deadnix

      # Shell script formatting and linting
      shellcheck
      shfmt

      # Markdown linting
      markdownlint-cli

      # Lua formatting
      stylua

      # TOML formatting
      taplo

      # YAML linting
      yamllint

      # Python formatting and linting (modern, fast)
      ruff

      # Spell checking for code
      typos

      # GitHub Actions linting
      actionlint

      # JSON formatting (jq is usually available, but ensure it)
      jq

      # General purpose formatter (kept for edge cases)
      nodePackages.prettier
    ];

    # Enable git system-wide configuration for pre-commit
    programs.git.enable = true;

    # Create helpful aliases for pre-commit management
    environment.shellAliases = {
      pc-install = "pre-commit install";
      pc-run = "pre-commit run --all-files";
      pc-update = "pre-commit autoupdate";
      pc-clean = "pre-commit clean";
    };

    # Add useful shell functions
    programs.zsh.interactiveShellInit = ''
      # Pre-commit helper functions
      pc-init() {
        if [ ! -f .pre-commit-config.yaml ]; then
          echo "No .pre-commit-config.yaml found in current directory"
          return 1
        fi
        pre-commit install
        echo "Pre-commit hooks installed successfully"
      }

      pc-check() {
        if [ -f .pre-commit-config.yaml ]; then
          echo "Running pre-commit checks..."
          pre-commit run --all-files
        else
          echo "No .pre-commit-config.yaml found"
          return 1
        fi
      }
    '';
  };
}
