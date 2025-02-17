{...}: {
  imports = [
    # ./hyprland/hypr.nix
    ./1password/1password.nix
    # ./steam/steam.nix
    ./gnupg/gnupg.nix
    ./dconf/dconf.nix
    ./sway/sway.nix
    ./nix-ld/default.nix
    ./firefox/default.nix
    ./wshowkeys/default.nix
    # ./streamcontroller/default.nix
    # ./thunar/default.nix
  ];
}
