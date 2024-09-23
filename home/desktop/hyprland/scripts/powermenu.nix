{pkgs, ...}:
pkgs.writeShellScriptBin "pmenu" ''
  # Theme Elements
  prompt="$(hostname)"
  mesg="Uptime : $(uptime)"

  # Options
  option_1=" Lock"
  option_2="  Logout"
  option_3="  Suspend"
  option_4="  Hibernate"
  option_5="  Reboot"
  option_6="  Shutdown"
  yes='󰄬 Yes'
  no=' No'

  # Rofi CMD
  rofi_cmd() {
  	rofi -theme-str "listview {columns: 6; lines: 1;}" \
  		-theme-str 'textbox-prompt-colon {str: "";}' \
  		-dmenu \
  		-p "$prompt" \
  		-markup-rows
  }

  # Pass variables to rofi dmenu
  run_rofi() {
  	echo -e "$option_1\n$option_2\n$option_3\n$option_4\n$option_5\n$option_6" | rofi_cmd
  }

  # Confirmation CMD
  confirm_cmd() {
  	rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; width: 350px;}' \
  		-theme-str 'mainbox {orientation: vertical; children: [ "message", "listview" ];}' \
  		-theme-str 'listview {columns: 2; lines: 1;}' \
  		-theme-str 'element-text {horizontal-align: 0.5;}' \
  		-theme-str 'textbox {horizontal-align: 0.5;}' \
  		-dmenu \
  		-p 'Confirmation' \
  		-mesg 'Are you Sure?'
  }

  # Ask for confirmation
  confirm_exit() {
  	echo -e "$yes\n$no" | confirm_cmd
  }

  # Confirm and execute
  confirm_run() {
  	selected="$(confirm_exit)"
  	if [[ "$selected" == "$yes" ]]; then
  		''${1} && ''${2} && ''${3}
  	else
  		exit
  	fi
  }

  # Execute Command
  run_cmd() {
  	if [[ "$1" == '--opt1' ]]; then
  		sleep 0.3 && swaylock
  	elif [[ "$1" == '--opt2' ]]; then
  		confirm_run 'hyprctl dispatch exit 1'
  	elif [[ "$1" == '--opt3' ]]; then
  		confirm_run 'systemctl suspend'
  	elif [[ "$1" == '--opt4' ]]; then
  		confirm_run 'systemctl hibernate'
  	elif [[ "$1" == '--opt5' ]]; then
  		confirm_run 'systemctl reboot'
  	elif [[ "$1" == '--opt6' ]]; then
  		confirm_run 'systemctl poweroff'
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
  $option_4)
  	run_cmd --opt4
  	;;
  $option_5)
  	run_cmd --opt5
  	;;
  $option_6)
  	run_cmd --opt6
  	;;
  esac
''
