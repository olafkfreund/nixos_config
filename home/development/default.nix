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
    ./claude-code-skills

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

    # Agent skills management (vercel-labs/skills CLI)
    ./skills-cli.nix
  ];

  # Always-on declarative skill: claude-code-mastery from borghei/Claude-Skills.
  # Symlinks into ~/.claude/skills/, complementing the ~18 imperatively
  # installed catalogues already there.
  programs.claude-code-skills.enable = true;
}
