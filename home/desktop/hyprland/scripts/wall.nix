{ pkgs, ... }:

pkgs.writeShellScriptBin "wall" ''
    FOLDER_PATH="/home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/"
    IMAGE=($(ls $FOLDER_PATH | shuf -n 1))
    wallsetter "$FOLDER_PATH/$IMAGE"
    # restart wall_schedule
    killall wall_schedule
    /home/olafkfreund/.config/hypr/scripts/wall_schedule &
''
