{pkgs, ...}:
pkgs.writeShellScriptBin "clockalternate" ''
  export LIFETIME=2000

  json_field () {
      echo -n "\"$1\":\"$2\""

      [[ "$3" == "1" ]] && echo -n ","
  }

  time_24h="$(date '+%H:%M')"
  time_12h="$(date '+%I:%M %p')"
  time_date="$(date '+%A, %B %d, %Y')"

  hit_a_click=1

  if [[ "$1" == "click-middle" ]]; then
      notify-send -e -t "''${LIFETIME}" "Uptime is..." "$(uptime -p | sed 's/up //')"
  elif [[ "$1" == "click-left" ]]; then
      notify-send -e -t "''${LIFETIME}" "The date is..." date '+%A, %B %d, %Y'
  elif [[ "$1" == "click-right" ]]; then
      notify-send -e -t "''${LIFETIME}" "12h -> 24h is..." "$time_12h -> $time_24h"
  else
      hit_a_click=0
  fi

  [[ $hit_a_click == 1 ]] && exit

  json_tooltip="$time_date"
  json_text="$time_12h"

  echo -n "{"
  json_field 'text' "$json_text" 1
  json_field 'tooltip' "$json_tooltip" 0
  echo "}"
''
