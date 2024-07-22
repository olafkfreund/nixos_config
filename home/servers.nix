{...}: {
  imports = [
    ./browsers/default.nix
    ./desktop/default-servers.nix
    ./git/git.nix
    ./shell/default.nix
    ./containers/default.nix
    ./VPN/tailscale.nix
    ./development/default.nix
    ./browsers/default.nix
    ./containers/default.nix
    ./files.nix
  ];
}
