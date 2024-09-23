{pkgs, ...}:
pkgs.writeShellScriptBin "monitors" ''
  # Theme Elements
  prompt='Monitors'
  mesg="Using '$BROWSER' as web browser"

  # Options
  option_1="󰌢 Laptop Monitor"
  option_2="󰍹 External Monitor"
  option_3="󰍺 Dual Monitors"

  # Rofi CMD
  rofi_cmd() {
    rofi -dmenu \
      -p "$prompt" \
      -markup-rows
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
