{pkgs, ...}:
pkgs.writeShellScriptBin "rofi-ddgr" ''
  # Theme Elements
  prompt="DuckDuckGo"
  mesg="Search the web with DuckDuckGo"

  # Rofi CMD with Gruvbox theme
  rofi_cmd() {
    rofi -theme "$HOME/.config/rofi/rofi-launcher-gruvbox-config.rasi" \
         -dmenu \
         -p "$prompt" \
         -mesg "$mesg" \
         -l 0
  }

  # Get search query from user
  query=$(rofi_cmd)

  # Exit if query is empty
  [[ -z "$query" ]] && exit 0

  # Check if ddgr is installed
  if ! command -v ddgr &> /dev/null; then
    notify-send "Error" "ddgr is not installed!" -u critical
    exit 1
  fi

  # Execute search
  # If a bang is used (e.g. !g for Google), open directly in GUI browser
  if [[ "$query" == \!* ]]; then
    ddgr --gb "$query"
  else
    # Show terminal with results
    # The --np flag is for "no prompt" to just display results and exit
    # Using for loop to handle numbered results selection

    # Create temporary file for results
    RESULTS_FILE=$(mktemp)

    # Run ddgr and store results
    ddgr --np --json "$query" > "$RESULTS_FILE"

    # Parse results and present in rofi
    TITLES=$(jq -r '.results[] | .title' "$RESULTS_FILE" | nl -w 2 -s '. ' | sed 's/^[ \t]*//')

    # Get selection from user
    SELECTION=$(echo "$TITLES" | rofi -theme "$HOME/.config/rofi/rofi-launcher-gruvbox-config.rasi" \
                                     -dmenu \
                                     -p "Results" \
                                     -i)

    # If user made a selection, open the URL in browser
    if [ -n "$SELECTION" ]; then
      # Extract the number from the selection (e.g. "1. Title" -> "1")
      NUM=$(echo "$SELECTION" | grep -o '^\s*[0-9]\+' | tr -d ' ')

      # Get the URL for the selected result (arrays are 0-indexed in jq)
      INDEX=$((NUM - 1))
      URL=$(jq -r ".results[$INDEX].url" "$RESULTS_FILE")

      # Open URL in browser
      if [ -n "$URL" ]; then
        xdg-open "$URL"
      fi
    fi

    # Clean up
    rm "$RESULTS_FILE"
  fi
''
