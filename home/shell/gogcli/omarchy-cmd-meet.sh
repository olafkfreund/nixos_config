# shellcheck shell=bash
# omarchy:summary=Create a Google Meet, copy the link, and join it
# omarchy:args=[--access open|trusted|restricted]
# omarchy:examples=omarchy-cmd-meet | omarchy-cmd-meet --access open

# trusted: signed-in Google users join directly, anyone else knocks.
# Pass --access open to let anyone with the link straight in.
access=trusted
[[ ${1:-} == --access && -n ${2:-} ]] && access=$2

if ! out=$(gog meet create --access "$access" --json 2>&1); then
  notify-send -u critical -a Omarchy "Meet failed" "${out:-gog meet create failed}"
  exit 1
fi

uri=$(jq -r '.meeting_uri // empty' <<<"$out")
[[ -n $uri ]] || {
  notify-send -u critical -a Omarchy "Meet failed" "No meeting_uri in response"
  exit 1
}

# Clipboard first: the link is the point, and it must survive the browser
# failing to launch.
printf '%s' "$uri" | wl-copy || true
notify-send -a Omarchy "Meet ready — link copied" "$uri" || true
xdg-open "$uri" >/dev/null 2>&1 &
