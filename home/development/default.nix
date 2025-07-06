# Enhanced Development Environment
# Complete development workflow with unified language support and productivity tools
{...}: {
  imports = [
    # Editor configurations (enhanced)
    ./vscode.nix
    ./nvim.nix
    ./emacs.nix
    ./zed.nix
    ./cursor-code.nix
    ./windsurf.nix
    
    # Development utilities
    ./distrobox.nix
    ./nixd.nix
    
    # Core language support and tooling
    ./languages.nix
    
    # Development workflow enhancements (conflicts resolved)
    ./workflow.nix
    ./productivity.nix
  ];
}
