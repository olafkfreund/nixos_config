{ ... }: {
  imports = [
    ./scripts.nix
    ./spell/spell.nix
    ./ai/chatgpt.nix
    ./ssh/ssh.nix
    ./system/system_util.nix
    ./stable_release_shell.nix
    ./lf/lf.nix
    ./bash.nix
    ./zsh.nix
    ./fish.nix
    ./starship/starship.nix
    ./system/utils.nix
    ./system/unpack.nix
    ./helpers/helpers.nix
    ./mail/mail.nix
    ./funny/funny.nix
    ./nix/nix_tools.nix
    ./fzf/default.nix
    ./direnv/default.nix
    ./yazi/default.nix
    ./zoxide/default.nix
    ./zellij/default.nix
    ./bat/default.nix
    ./lunarvim/default.nix
    ./vim/default.nix
    ./tmux/default.nix
    ./translate-shell/default.nix
    ./xdg/default.nix
    ./lazyvim/default.nix

  ];
}
