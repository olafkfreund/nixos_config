{...}: {
  imports = [
    ./shell/bash.nix
    ./shell/zsh.nix
    ./shell/starship.nix
    ./shell/utils.nix
    ./git/git.nix
    ./games/steam.nix
    ./desktop/default.nix
    ./desktop/terminals.nix
    ./browsers/default.nix
    ./shell/spell.nix
    ./shell/chatgpt.nix
    ./shell/ssh.nix
    ./desktop/com.nix
    ./shell/system_util.nix
    ./shell/unpack
    ./shell/system
    ./shell/helpers
    ./media/spice_themes.nix
    ./media/music.nix
    ./development/default.nix
    ./cloud/default.nix
    ./containers/default.nix
  ];
}
