{ pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Development tools
    git
    vim
    tmux
    zsh
    curl
    wget
    bat
    fd
    ripgrep
    fzf
    jq
    tree
    exa
    tldr
    bat
    starship
    kubetail
    kubectl
    helm
    werf
    k9s
    neovim
    lunarvim
    lazygit
    just
    freerdp3
}
