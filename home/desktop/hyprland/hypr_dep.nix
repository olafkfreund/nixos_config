{pkgs, ...}: {
  home.packages = with pkgs; [
    eww
    swww
    cliphist
    grim
    slurp
    swayidle
    swaylock
    swaybg

    swappy
    hyprnome
    hyprshot
    hyprdim
    hyprlock
    hypridle
    hyprpaper
    emote
    python311Packages.requests
    betterlockscreen
    watershot
    xdg-utils
    glib
    hyprkeys
    nwg-displays
    kanshi
    wl-clipboard
    wl-screenrec
    hyprcursor
  ];
}
