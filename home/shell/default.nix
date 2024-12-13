{...}: {
  imports = [
    ./scripts.nix
    ./lf/lf.nix
    ./bash.nix
    ./zsh.nix
    ./starship/starship.nix
    ./mail/mail.nix
    ./fzf/default.nix
    ./direnv/default.nix
    ./yazi/default.nix
    ./zoxide/default.nix
    ./zellij/default.nix
    ./bat/default.nix
    # ./lunarvim/default.nix
    ./tmux/default.nix
    ./lazyvim/default.nix
    ./markdown/default.nix
    ./gh/default.nix
  ];
}
