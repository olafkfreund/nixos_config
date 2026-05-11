# Primary Development Shell Environment
#
# Intentionally slim. Anything you'd reach for during ordinary edit / build /
# commit work lives here. Tools used only occasionally (mdbook, graphviz,
# typos, taplo, nix-tree, nix-diff, nix-eval-jobs, commitizen, …) were moved
# out because each drags in a hefty closure (Haskell GHC for nix-tree,
# python+toolchains for commitizen, full LLVM/clang for some build-time deps,
# even an arm64 .NET runtime via transitives) — collectively ~9 GB the
# direnv-loaded shell doesn't need on a daily basis. Reach for them via:
#
#   nix develop .#docs                # mdbook, graphviz, typos, taplo, ...
#   nix shell nixpkgs#nix-tree        # one-off nix introspection
#   nix shell nixpkgs#nix-diff
#   nix shell nixpkgs#nix-eval-jobs
#   nix shell nixpkgs#commitizen
#
{ pkgs, ... }:
pkgs.mkShell {
  name = "nixos-dev-environment";

  packages = with pkgs; [
    # Nix LSP + build UX
    nixd # Advanced LSP server (nil dropped — nixd is the better LSP)
    nix-output-monitor # prettier build output

    # Linters + formatter (run on every edit / pre-commit)
    nixpkgs-lint-community # Primary linter (tree-sitter, whole-tree-safe)
    statix # Secondary linter (rule-based: `statix check FILE`)
    deadnix # Dead-code detection
    nixpkgs-fmt # Formatter

    # Workflow
    just # Command runner
    pre-commit # Git hooks (pre-commit hook fires on every commit)

    # System tools any shell command in this repo expects
    git
    curl
    jq

    # direnv integration
    direnv
    nix-direnv
  ];

  shellHook = ''
    export PATH=$PWD/scripts:$PATH
    echo "🚀 NixOS Development Environment v2.1 (slim)"
    echo ""
    echo "📋 Common commands:"
    echo "  just validate        - Complete validation suite"
    echo "  just test-host X     - Test specific host config"
    echo "  just quick-deploy X  - Smart deploy (only if changed)"
    echo "  just update-commit   - update + build + commit (no switch)"
    echo ""
    echo "🔧 Linters / formatter (in this shell):"
    echo "  nixpkgs-lint .       - Fast tree-sitter lint (whole tree)"
    echo "  statix check FILE    - Rule-based lint (single file)"
    echo "  deadnix              - Dead-code detection"
    echo "  nixpkgs-fmt          - Format"
    echo ""
    echo "📦 Occasional tools (NOT in this shell — reach via):"
    echo "  nix develop .#docs           # mdbook, graphviz, typos, taplo"
    echo "  nix shell nixpkgs#nix-tree   # dependency visualisation"
    echo "  nix shell nixpkgs#nix-diff   # closure comparison"
    echo ""

    # Initialise pre-commit if the hook isn't installed
    if [ ! -f .git/hooks/pre-commit ]; then
      echo "🔨 Initialising pre-commit hooks..."
      pre-commit install --install-hooks 2>/dev/null || echo "Pre-commit setup skipped"
    fi
  '';

  # Environment
  NIX_CONFIG = "experimental-features = nix-command flakes";
  NIXPKGS_ALLOW_UNFREE = "1";
  DIRENV_LOG_FORMAT = "";
}
