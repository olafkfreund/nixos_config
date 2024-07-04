{ pkgs, ... }:

pkgs.writeShellScriptBin "monitors" ''
# Import Current Theme
    source "$HOME"/.config/rofi/applets/shared/theme.bash
    theme="$type/$style"

# Theme Elements
    prompt='Monitors'
    mesg="Using '$BROWSER' as web browser"

    if [[ ( "$theme" == *'type-1'* ) || ( "$theme" == *'type-3'* ) || ( "$theme" == *'type-5'* ) ]]; then
      list_col='1'
      list_row='3'
    elif [[ ( "$theme" == *'type-2'* ) || ( "$theme" == *'type-4'* ) ]]; then
      list_col='3'
      list_row='1'
    fi

    if [[ ( "$theme" == *'type-1'* ) || ( "$theme" == *'type-5'* ) ]]; then
      efonts="JetBrains Mono Nerd Font 10"
    else
      efonts="JetBrains Mono Nerd Font 28"
    fi

# Options
    layout=`cat ''${theme} | grep 'USE_ICON' | cut -d'=' -f2`
    if [[ "$layout" == 'NO' ]]; then
      option_1="󰌢 Laptop Monitor"
      option_2="󰍹 External Monitor"
      option_2="󰍺 Dual Monitors"
    else
      option_1=" "
      option_2="󰍹 "
      option_3="󰍺 "
    fi

# Rofi CMD
    rofi_cmd() {
      rofi -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -theme-str 'textbox-prompt-colon {str: "";}' \
        -theme-str "element-text {font: \"$efonts\";}" \
        -dmenu \
        -p "$prompt" \
        -mesg "$mesg" \
        -markup-rows \
      -theme "''${theme}"
  }

# Pass variables to rofi dmenu
  run_rofi() {
    echo -e "$option_1\n$option_2\n$option_3" | rofi_cmd
  }

# Execute Command
  run_cmd() {
    if [[ "$1" == '--opt1' ]]; then
      wlr-randr --output eDP-1 --on
      wlr-randr --output HDMI-A-1 --off
    elif [[ "$1" == '--opt2' ]]; then
      wlr-randr --output eDP-1 --off
      wlr-randr --output HDMI-A-1 --on
      hyprctl keyword monitor "HDMI-A-1,3840x2160@120,0x0,1.5,bitdepth,10"
    elif [[ "$1" == '--opt3' ]]; then
      wlr-randr --output eDP-1 --on
      wlr-randr --output HDMI-A-1 --on
    fi
  }

# Actions
  chosen="$(run_rofi)"
  case ''${chosen} in
      $option_1)
      run_cmd --opt1
          ;;
      $option_2)
      run_cmd --opt2
          ;;
      $option_3)
      run_cmd --opt3
          ;;
  esac
''
