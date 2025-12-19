_: {
  # Development-related modules
  # Only load on hosts that do development work
  imports = [
    ./ai/default.nix
    ./helpers/helpers.nix
    ./shell/zsh-ai-cmd.nix # AI-powered shell command suggestions
    # Note: ./development/default.nix is imported separately in hosts
  ];
}
