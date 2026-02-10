# Primary Development Shell Environment
{ pkgs, ... }:
pkgs.mkShell {
  name = "nixos-dev-environment";

  packages = with pkgs; [
    # Modern Nix tooling
    nixd # Advanced LSP server
    nil # Alternative LSP
    nix-output-monitor # Beautiful build output
    nix-tree # Dependency visualization
    nix-diff # Configuration comparison
    nix-eval-jobs # Parallel evaluation

    # Development workflow
    just # Command runner (already using)
    pre-commit # Git hooks
    commitizen # Conventional commits

    # Quality assurance
    statix # Advanced linting
    deadnix # Dead code detection
    nixpkgs-fmt # Code formatting
    typos # Spell checking
    taplo # TOML formatting

    # Documentation and analysis
    mdbook # Documentation generation
    graphviz # Dependency graphs

    # System tools
    git # Version control
    curl # HTTP requests
    jq # JSON processing

    # Development utilities
    direnv # Environment management
    nix-direnv # Nix integration for direnv
  ];

  shellHook = ''
    export PATH=$PWD/scripts:$PATH
    echo "🚀 NixOS Development Environment v2.0"
    echo ""
    echo "📋 Available Commands:"
    echo "  just validate        - Complete validation suite"
    echo "  just test-host X     - Test specific host config"
    echo "  just deploy-all      - Deploy all hosts"
    echo "  just quick-test      - Fast parallel testing"
    echo "  just quick-all       - Test and deploy all"
    echo ""
    echo "🔧 Development Tools:"
    echo "  nixd                - Start LSP server"
    echo "  statix check        - Lint all Nix files"
    echo "  deadnix             - Check for dead code"
    echo "  nix-tree            - Visualize dependencies"
    echo "  nix-diff .#old .#new - Compare configurations"
    echo ""
    echo "📚 Documentation:"
    echo "  mdbook build        - Generate documentation"
    echo "  nix flake show      - Show flake outputs"
    echo ""

    # Initialize pre-commit if not already done
    if [ ! -f .git/hooks/pre-commit ]; then
      echo "🔨 Initializing pre-commit hooks..."
      pre-commit install --install-hooks 2>/dev/null || echo "Pre-commit setup skipped"
    fi

    # Setup direnv if .envrc doesn't exist
    if [ ! -f .envrc ] && command -v direnv >/dev/null 2>&1; then
      echo "use flake" > .envrc
      echo "📂 Created .envrc for automatic environment loading"
    fi
  '';

  # Environment variables for development
  NIX_CONFIG = "experimental-features = nix-command flakes";
  NIXPKGS_ALLOW_UNFREE = "1";
  DIRENV_LOG_FORMAT = "";
}
