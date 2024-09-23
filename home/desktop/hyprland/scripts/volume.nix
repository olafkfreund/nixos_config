{pkgs, ...}:
pkgs.writeShellScriptBin "volume" ''
  # Volume Info
  mixer="$(amixer info Master | grep 'Mixer name' | cut -d':' -f2 | tr -d \',' ')"
  speaker="$(amixer get Master | tail -n1 | awk -F ' ' '{print $5}' | tr -d '[]')"
  mic="$(amixer get Capture | tail -n1 | awk -F ' ' '{print $5}' | tr -d '[]')"

  active=""
  urgent=""

  # Speaker Info
  amixer get Master | grep '\[on\]' &>/dev/null
  if [[ "$?" == 0 ]]; then
  	active="-a 1"
  	stext='Unmute'
  	sicon='󰕾 '
  else
  	urgent="-u 1"
  	stext='Mute'
  	sicon='󰖁 '
  fi

  # Microphone Info
  amixer get Capture | grep '\[on\]' &>/dev/null
  if [[ "$?" == 0 ]]; then
  	[ -n "$active" ] && active+=",3" || active="-a 3"
  	mtext='Unmute'
  	micon='󰍬'
  else
  	[ -n "$urgent" ] && urgent+=",3" || urgent="-u 3"
  	mtext='Mute'
  	micon=''
  fi

  # Theme Elements
  prompt="S:$stext, M:$mtext"
  mesg="$mixer - Speaker: $speaker, Mic: $mic"

  # Options
  option_1="󰝝 Increase"
  option_2="$sicon $stext"
  option_3="󰝞  Decrese"
  option_4="$micon $mtext"
  option_5=" Settings"

  # Rofi CMD
  rofi_cmd() {
  	rofi -theme-str "window {width: 670px;}" \
  		-theme-str "listview {columns: 5; lines: 1;}" \
  		-theme-str 'textbox-prompt-colon {str: "";}' \
  		-dmenu \
  		-p "$prompt" \
  		-mesg "$mesg" \
  		''${active} ''${urgent} \
  		-markup-rows 
  }

  # Pass variables to rofi dmenu
  run_rofi() {
  	echo -e "$option_1\n$option_2\n$option_3\n$option_4\n$option_5" | rofi_cmd
  }

  # Execute Command
  run_cmd() {
  	if [[ "$1" == '--opt1' ]]; then
  		amixer -Mq set Master,0 5%+ unmute
  	elif [[ "$1" == '--opt2' ]]; then
  		amixer set Master toggle
  	elif [[ "$1" == '--opt3' ]]; then
  		amixer -Mq set Master,0 5%- unmute
  	elif [[ "$1" == '--opt4' ]]; then
  		amixer set Capture toggle
  	elif [[ "$1" == '--opt5' ]]; then
  		pavucontrol
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
  esac
''
