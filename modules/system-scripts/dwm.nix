
{ pkgs, ... }:

pkgs.writeShellScriptBin "dwm-run" ''

xrdb merge ~/.Xresources 
feh --randomize --bg-fill ~/Pictures/wallpapers/gruvbox/hypr/*.* &
picom --animation &
dwmblocks &

while true; do
    dwm 2> ~/.dwm.log
done

''
