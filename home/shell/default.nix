{...}: {
  imports = [
    ./bash.nix
    ./bat
    ./claude-integration.nix
    ./direnv
    ./fastfetch
    ./fzf
    ./gh
    ./lazygit
    # LazyVim can remain installed alongside NixVim until you're ready to fully switch
    ./lazyvim
    # Add the new NixVim configuration
    ./nixvim
    ./lf
    ./lunarvim
    ./mail
    ./man
    ./markdown
    ./ssh
    ./starship
    ./tmux
    ./yazi
    ./zellij
    ./zoxide
    ./zsh.nix
  ];
}
