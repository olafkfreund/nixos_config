{ pkgs, ... }:

let
  wallpaperDir = "/home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/";
  cacheDir="$HOME/.cache/jp/gruvbox";
in
pkgs.writeShellScriptBin "wallpaper_picker" ''
  wall_dir="$HOME/Pictures/wallpapers/gruvbox/hypr"
  
  rofi_command="rofi -dmenu -theme ./wallSelect.rasi"

  # Create cache dir if not exists
  if [ ! -d "${cacheDir}" ] ; then
          mkdir -p "${cacheDir}"
      fi


  physical_monitor_size=27
  monitor_res=$(hyprctl monitors |grep -A2 Monitor |head -n 2 |awk '{print $1}' | grep -oE '^[0-9]+')
  dotsperinch=$(echo "scale=2; $monitor_res / $physical_monitor_size" | bc | xargs printf "%.0f")
  monitor_res=$(( $monitor_res * $physical_monitor_size / $dotsperinch ))
  rofi_override="element-icon{size:"$monitor_res"px;border-radius:0px;}"

  # Convert images in directory and save to cache dir
  for imagen in "$wall_dir"/*.{jpg,jpeg,png,webp}; do
    if [ -f "$imagen" ]; then
      archive=$(basename "$imagen")
        if [ ! -f "${cacheDir}/"$archive"" ] ; then
          convert -strip "$imagen" -thumbnail 500x500^ -gravity center -extent 500x500 "${cacheDir}/"$archive""
        fi
      fi
  done

  # Select a picture with rofi
  wall_selection=$(find "${wallpaperDir}"  -maxdepth 1  -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -exec basename {} \; | sort | while read -r A ; do  echo -en "$A\x00icon\x1f""${cacheDir}"/"$A\n" ; done | $rofi_command)

  # Set the wallpaper
  [[ -n "$wall_selection" ]] || exit 1
  swww img ${wallpaperDir}/$wall_selection

  exit 0
''