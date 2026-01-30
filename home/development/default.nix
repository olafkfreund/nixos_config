# Enhanced Development Environment
# Complete development workflow with unified language support and productivity tools
_: {
  imports = [
    # Editor configurations (enhanced)
    ./vscode.nix
    ./nvim.nix
    ./cursor-code.nix
    ./windsurf.nix

    # Development utilities
    ./distrobox.nix
    ./nixd.nix

    # AI-powered development tools
    ./codex-cli.nix
    ./claude-desktop
    ./claude-powerline.nix
    # ./moltbot # DISABLED: nix-moltbot flake structure changed, needs update

    # Version control and CI/CD
    ./gitlab/default.nix

    # Core language support and tooling
    ./languages.nix

    # LSP servers for Claude Code and other editors
    ./lsp-servers.nix
    ./claude-code-lsp.nix
    ./claude-code-mcp.nix # Claude Code MCP server configuration

    # Development workflow enhancements (conflicts resolved)
    ./workflow.nix
    ./productivity.nix
  ];
}
