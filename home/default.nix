{...}: {
  imports = [
    ./browsers/default.nix
    ./desktop/default.nix
    ./desktop/com.nix
    ./desktop/terminals.nix
    ./git/git.nix
    ./games/steam.nix
    ./shell/spell/spell.nix
    ./shell/ai/chatgpt.nix
    ./shell/ssh/ssh.nix
    ./shell/system/system_util.nix
    ./shell/stable_release_shell.nix
    ./shell/lf/lf.nix
    ./shell/bash.nix
    ./shell/zsh.nix
    ./shell/starship/starship.nix
    ./shell/system/utils.nix
    ./shell/system/unpack.nix
    ./shell/helpers/helpers.nix
    ./shell/mail/mail.nix
    ./shell/funny/funny.nix
    ./shell/nix/nix_tools.nix
    ./media/music.nix
    ./containers/distrobox.nix
    ./VPN/tailscale.nix
];
}
