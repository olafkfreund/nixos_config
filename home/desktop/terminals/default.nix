{pkgs, ...}: {
  imports = [
    ./wezterm/default.nix
    ./alacritty/default.nix
    ./kitty/default.nix
  ];
}
