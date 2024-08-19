{ ... }: {
  imports = [
    ./hyprland/hypr.nix
    ./1password/1password.nix
    ./steam/steam.nix
    ./gnupg/gnupg.nix
    ./dconf/dconf.nix
    ./nix-ld/default.nix
    ./firefox/default.nix
    ./wshowkeys/default.nix
    # ./thunar/default.nix
  ];
}
