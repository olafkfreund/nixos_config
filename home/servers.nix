{...}: {
  imports = [
    ./browsers/default.nix
    ./desktop/default-servers.nix
    ./shell/default.nix
    ./containers/default.nix
    ./VPN/tailscale.nix
    ./development/default.nix
    ./containers/default.nix
    ./files.nix
  ];
}
