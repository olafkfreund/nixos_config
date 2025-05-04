{pkgs, ...}: {
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
    # pkgs.hyprgui
  ];
}
