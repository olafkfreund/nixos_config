# Enhanced Development Environment
# Complete development workflow with unified language support and productivity tools
_: {
  imports = [
    # Editor configurations (enhanced)
    ./vscode.nix
    ./nvim.nix
    ./cursor-code.nix
    ./windsurf.nix
    ./zed-editor.nix

    # Development utilities
    ./distrobox.nix
    ./nixd.nix

    # AI-powered development tools
    ./codex-cli.nix
    ./claude-desktop
    ./claude-powerline.nix
    ./claude-code-skills
    ./claude-code-commands
    ./herdr.nix # herdr agent-multiplexer config (p620 + razer)

    # Version control and CI/CD
    ./gitlab/default.nix

    # Core language support and tooling
    ./languages.nix
    ./npm-prefix.nix # writable npm/npx global prefix (nodejs-slim has no lib/)

    # LSP servers for Claude Code and other editors
    ./lsp-servers.nix
    ./claude-code-lsp.nix
    ./claude-code-mcp.nix # Claude Code MCP server configuration
    ./antigravity-config.nix # Declarative Antigravity rules + MCP sync
    ./claude-code-output-styles.nix # Declarative Claude Code output styles
    ./claude-code-agents.nix # Declarative agent curation (hide irrelevant agents)

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
  programs.claude-code-commands.enable = true;
}
