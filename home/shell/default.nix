{...}: {
  imports = [
    ./scripts.nix
    ./lf/default.nix
    ./bash.nix
    ./zsh.nix
    ./starship/default.nix
    ./mail/default.nix
    ./fzf/default.nix
    ./direnv/default.nix
    ./yazi/default.nix
    ./zoxide/default.nix
    ./zellij/default.nix
    ./bat/default.nix
    # ./lunarvim/default.nix
    ./tmux/default.nix
    ./lazyvim/default.nix # Disabled as we've migrated to NixVim
    ./markdown/default.nix
    ./gh/default.nix
    ./fastfetch/default.nix
    ./clipse/default.nix
    ./nixvim/default.nix # Added NixVim configuration
  ];
}
