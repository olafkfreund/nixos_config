{ pkgs, ... }:

pkgs.writeShellScriptBin "start_wall" ''
    rm -rf "$XDG_RUNTIME_DIR/swww.socket"
    rm -rf ~/.cache/swww/*
    swww kill && swww clear-cache && swww-daemon --format xrgb|| swww-daemon --format xrgb 
    IMG_NAME=$(ls /home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/ | shuf -n 1)
    IMG_PATH_FULL=$HOME"/Pictures/wallpapers/gruvbox/hypr/"$IMG_NAME
    wallsetter "$IMG_PATH_FULL"
    /home/olafkfreund/.config/hypr/scripts/wall_schedule &
''
