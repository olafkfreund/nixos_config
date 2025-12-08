# Documentation Development Shell
{ pkgs, ... }:
pkgs.mkShell {
  name = "nixos-docs-environment";

  packages = with pkgs; [
    # Documentation generation
    mdbook # Rust-based documentation
    mdbook-mermaid # Mermaid diagram support
    mdbook-toc # Table of contents generation

    # Diagram and visualization
    graphviz # Graph visualization
    plantuml # UML diagrams
    mermaid-cli # Mermaid diagram CLI

    # Documentation tools
    pandoc # Document conversion
    texlive.combined.scheme-medium # LaTeX for PDF generation

    # NixOS documentation tools
    nixos-option # Option documentation
    nix-doc # Nix documentation

    # Web and preview
    python3Packages.livereload # Live preview server

    # Text processing
    ripgrep # Fast text search
    fd # Fast file finding
    bat # Better cat with syntax highlighting

    # Git and version control
    git
    git-cliff # Changelog generation

    # Linting and formatting
    markdownlint-cli # Markdown linting
    vale # Prose linting
  ];

  shellHook = ''
    echo "📚 NixOS Documentation Environment"
    echo ""
    echo "📖 Documentation Generation:"
    echo "  mdbook init         - Initialize new book"
    echo "  mdbook build        - Build documentation"
    echo "  mdbook serve        - Serve with live reload"
    echo ""
    echo "📊 Visualization:"
    echo "  nix-tree            - Dependency trees"
    echo "  dot -Tpng file.dot  - Generate PNG from GraphViz"
    echo "  plantuml diagram.puml - Generate UML diagrams"
    echo ""
    echo "🔍 Analysis Tools:"
    echo "  nixos-option -I .   - Generate option docs"
    echo "  nix-doc             - Extract Nix documentation"
    echo "  rg                  - Fast text search"
    echo ""
    echo "✅ Quality Assurance:"
    echo "  markdownlint **/*.md - Lint markdown files"
    echo "  vale **/*.md        - Prose linting"
    echo ""
  '';

  # Environment for documentation work
  MDBOOK_PREPROCESSOR__MERMAID__COMMAND = "${pkgs.mdbook-mermaid}/bin/mdbook-mermaid";
  NIX_CONFIG = "experimental-features = nix-command flakes";
}
