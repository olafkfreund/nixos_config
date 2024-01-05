{ pkgs, ... }: {

home.packages = with pkgs; [
  swayr
  swayws
  swaybg
  swayosd
  swayimg
  swayrbar
  swaykbdd
  swayidle
  swaytools
  swaysettings
  swaynag-battery
  swaylock-effects
  autotiling-rs
  nwg-panel
  wmenu
  waybar
  wofi
  waypaper
  wayshot
  ];
}
