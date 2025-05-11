{pkgs, ...}: {
  imports = [
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

  home.packages = [
    pkgs.eww
    pkgs.swww
    pkgs.cliphist
    pkgs.grim
    pkgs.slurp
    pkgs.swayidle
    pkgs.swaylock
    pkgs.swaybg
    pkgs.wf-recorder
    pkgs.swappy
    pkgs.hyprnome
    pkgs.hyprshot
    pkgs.hyprdim
    pkgs.hyprlock
    pkgs.hypridle
    pkgs.python312Packages.requests
    pkgs.betterlockscreen
    pkgs.watershot
    pkgs.xdg-utils
    pkgs.glib
    pkgs.hyprkeys
    pkgs.nwg-displays
    pkgs.kanshi
    pkgs.wl-clipboard
    pkgs.wl-screenrec
    pkgs.hyprcursor
    pkgs.sherlock-launcher
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
      pkgs.hyprlandPlugins.hyprbars
    ];
  };
}
