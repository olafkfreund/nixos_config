{
  inputs,
  lib,
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  imports = [
    ./hypr_dep.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./config/env.nix
    ./config/binds.nix
    ./config/input.nix
    ./config/rules.nix
    ./config/autostart.nix
    ./config/plugins.nix
    ./config/monitors.nix
    ./config/settings.nix
    ./config/workspace.nix
    ./scripts/packages.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
      # pkgs.hyprlandPlugins.hyprfocus
      pkgs.hyprlandPlugins.hyprbars
    ];
  };
}
