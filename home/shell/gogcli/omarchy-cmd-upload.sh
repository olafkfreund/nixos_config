# omarchy:summary=Upload a file to Google Drive and copy its link
# omarchy:args=[path]
# omarchy:examples=omarchy-cmd-upload | omarchy-cmd-upload ~/Pictures/shot.png

ACCOUNT=${GOG_ACCOUNT:-olaf@freundcloud.com}

path=${1:-}
[[ -n $path ]] || path=$(gum file "${HOME}" || true)
[[ -n $path ]] || exit 0 # cancelled

# Validate before spending an upload: gum file can return a directory, and an
# unreadable path would otherwise surface as an opaque gog error.
[[ -f $path && -r $path ]] || {
  notify-send -u critical -a Omarchy "Upload failed" "Not a readable file: $path"
  exit 1
}

# ponytail: no progress UI — fine for the screenshots and documents this is for.
# If large uploads become normal, wrap in `gum spin` when stdout is a TTY.
if out=$(gog drive upload "$path" --account "$ACCOUNT" --json 2>&1); then
  link=$(jq -r '.file.webViewLink // empty' <<<"$out")
  if [[ -n $link ]]; then
    printf "%s" "$link" | wl-copy || true
    notify-send -a Omarchy "Uploaded to Drive" "$(basename "$path") — link copied" || true
  else
    notify-send -a Omarchy "Uploaded to Drive" "$(basename "$path")" || true
  fi
else
  notify-send -u critical -a Omarchy "Upload failed" "${out:-gog drive upload failed}"
  exit 1
fi
