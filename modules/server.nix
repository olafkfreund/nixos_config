_: {
  imports = [
    ./nix/nix.nix
    ./fonts/fonts.nix
    ./programs/default.nix
    ./services/default.nix
    ./security/default.nix
    ./virt/default.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    # ./nix-index/default.nix
    ./containers/default.nix
  ];
}
