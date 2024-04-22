#!/usr/bin/env bash
$(swww kill && swww init)|| swww init
IMG_NAME=$(ls /home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/ | shuf -n 1)
IMG_PATH_FULL=$HOME"/Pictures/wallpapers/gruvbox/hypr/"$IMG_NAME
set_background.sh "$IMG_PATH_FULL"
/home/olafkfreund/.config/hypr/scripts/wall_schedule &