{ pkgs, ... }:

pkgs.writeShellScriptBin "dwm-run" ''
xrdb merge ~/.Xresources 
feh --randomize --bg-fill ~/Pictures/wallpapers/gruvbox/hypr/*.* &
exec picom &
exec dwmblocks &
exec dwm
''
