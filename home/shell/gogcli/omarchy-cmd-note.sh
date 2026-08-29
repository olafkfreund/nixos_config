# shellcheck shell=bash
# omarchy:summary=Capture a quick note into Google Tasks
# omarchy:args=[note text...]
# omarchy:examples=omarchy-cmd-note | omarchy-cmd-note "Call the dentist"

# The "Private" list. Overridable because the id is opaque and would change if
# the list were ever deleted and recreated; `gog tasks lists` prints the new one.
TASKLIST=${GOG_TASKLIST:-aFRDVDU4N2ZVaGxwOENqUA}
ACCOUNT=${GOG_ACCOUNT:-olaf@freundcloud.com}

note=$*
[[ -n $note ]] || note=$(gum input --placeholder "Note…" --prompt "note> " || true)
[[ -n $note ]] || exit 0 # empty or cancelled: nothing to capture, not an error

if err=$(gog tasks add "$TASKLIST" --account "$ACCOUNT" --title "$note" --json 2>&1 >/dev/null); then
  # A dead notification daemon (headless, hooks, agents) must not turn a
  # saved note into a reported failure under set -e.
  notify-send -a Omarchy "Note saved" "$note" || true
else
  # Never fail silently — a dropped note is lost data, and the shell that
  # launched this has nowhere to show stderr.
  notify-send -u critical -a Omarchy "Note failed" "${err:-gog tasks add failed}"
  exit 1
fi
