{ pkgs, ... }: {

home.packages = with pkgs; [
  eww
  swww
  # waypaper
  # wl-clipboard
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
  onlyoffice-bin_latest
  watershot
  ];
}
