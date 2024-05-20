#!/usr/bin/env bash
FOLDER_PATH="/home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/"
IMAGE=($(ls $FOLDER_PATH | shuf -n 1))
set_background.sh "$FOLDER_PATH/$IMAGE"
# restart wall_schedule
killall wall_schedule
/home/olafkfreund/.config/hypr/scripts/wall_schedule &