{ ... }: {
  # One Wayland session config per compositor, plus the shell/theming shared by
  # all of them. Values common to every session live in ./common.nix.
  imports = [
    ./shell.nix
    ./niri.nix
    ./labwc.nix
    ./mango.nix
    ./hyprland.nix
  ];
}
