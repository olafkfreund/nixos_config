_: {
  # Desktop environment modules
  # Only load on hosts with desktop environments
  imports = [
    ./desktop/default.nix
    ./desktop/wlr/default.nix
    ./desktop/remote/default.nix
    ./desktop/cloud-sync/default.nix
    ./desktop/vnc/default.nix
    ./desktop/gtk/default.nix
    ./desktop/hyprland/hyprland-stack3d.nix
    ./fonts/fonts.nix
  ];
}
