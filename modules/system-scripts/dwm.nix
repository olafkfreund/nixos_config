
{ pkgs, ... }:

pkgs.writeShellScriptBin "dwm-run" ''

xrdb merge ~/.Xresources 
xbacklight -set 10 &
feh --randomize --bg-fill ~/Pictures/wallpapers/gruvbox/hypr/*.* &
xset r rate 200 50 &
picom --animation &

dash ~/.config/chadwm/scripts/bar.sh &
while type chadwm >/dev/null; do chadwm && continue || break; done'
''
