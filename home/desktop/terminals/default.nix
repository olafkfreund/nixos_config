{pkgs, ...}: {
  imports = [
    ./wezterm/default.nix
    ./alacritty/default.nix
  ];
}