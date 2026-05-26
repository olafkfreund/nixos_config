_: {
  imports = [
    ./scripts.nix
    ./lf/default.nix
    ./bash.nix
    ./zsh.nix
    ./zsh-ai-cmd.nix # AI-powered shell command suggestions
    ./splashboard # Terminal splash screen on shell startup
    ./gogcli # gogcli collector feeding splashboard email/tasks/events widgets
    ./starship/default.nix
    ./mail/default.nix
    ./fzf/default.nix
    ./direnv/default.nix
    ./yazi/default.nix
    ./zoxide/default.nix
    ./zellij/default.nix
    ./bat/default.nix
    ./tmux/default.nix
    ./rmux/default.nix # multiplexer config + alias auto-loading it
    ./lazyvim/default.nix
    ./markdown/default.nix
    ./gh/default.nix
    ./fastfetch/default.nix
    ./clipse/default.nix
  ];
}
