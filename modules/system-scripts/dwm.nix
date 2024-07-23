
{ pkgs, ... }:

pkgs.writeShellScriptBin "dwm-run" ''

xrdb merge ~/.Xresources 
feh --randomize --bg-fill ~/Pictures/wallpapers/gruvbox/hypr/*.* &
picom --animation &

dash ~/.config/chadwm/scripts/bar.sh &
# while type chadwm >/dev/null; do chadwm && continue || break; done
while xsetroot -name "`date` `uptime | sed 's/.*,//'`"
 do
  sleep 1
done 
''
