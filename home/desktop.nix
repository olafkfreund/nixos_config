{...}: {
  imports = [
    ./browsers/default.nix
    ./desktop/default.nix
    ./git/github.nix
    ./shell/default.nix
    ./media/music.nix
    ./VPN/tailscale.nix
    ./development/default.nix
    ./media/music.nix
    ./media/spice_themes.nix
    ./files.nix
  ];
}
