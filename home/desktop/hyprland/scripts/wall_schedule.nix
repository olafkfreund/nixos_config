{ pkgs, ... }:

pkgs.writeShellScriptBin "wall_schedule" ''
    FOLDER_PATH="/home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/"
    LIST=($(ls $FOLDER_PATH | shuf))
    for image in "$(LIST[@])"; do
        sleep 1h
        wallsetter "$FOLDER_PATH/$image"
    done
    do
        sleep 1h
        wallsetter "$FOLDER_PATH/$image"
done
''
