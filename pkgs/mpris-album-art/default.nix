{
  pkgs,
  ...
}:
pkgs.writeShellScriptBin "mpris-album-art" ''
  #!/usr/bin/env bash
  # mpris-album-art: Shows the album art of currently playing media using MPRIS

  # Exit if no media is playing
  if ! ${pkgs.playerctl}/bin/playerctl status &>/dev/null; then
    echo "No media player detected"
    exit 1
  fi

  # Get the active player
  PLAYER=$(${pkgs.playerctl}/bin/playerctl -p spotify | head -n 1)
  if [ -z "$PLAYER" ]; then
    echo "No active player found"
    exit 1
  fi

  # Get metadata
  TITLE=$(${pkgs.playerctl}/bin/playerctl -p spotify metadata title 2>/dev/null)
  ARTIST=$(${pkgs.playerctl}/bin/playerctl -p spotify metadata artist 2>/dev/null)
  ALBUM=$(${pkgs.playerctl}/bin/playerctl -p spotify metadata album 2>/dev/null)
  ART_URL=$(${pkgs.playerctl}/bin/playerctl -p spotify metadata mpris:artUrl 2>/dev/null)

  echo "Now playing: $TITLE by $ARTIST"
  echo "Album: $ALBUM"

  # If no art URL found
  if [ -z "$ART_URL" ]; then
    echo "No album art found"
    exit 1
  fi

  # Create temp directory if it doesn't exist
  TEMP_DIR="/tmp/album_art"
  mkdir -p "$TEMP_DIR"

  # Sanitize filename
  FILENAME=$(echo "$ARTIST-$ALBUM" | tr -dc '[:alnum:]._-' | tr -s '._-' | tr '[:upper:]' '[:lower:]')
  if [ -z "$FILENAME" ]; then
    FILENAME="album_art"
  fi

  # Define output path
  OUTPUT_PATH="$TEMP_DIR/$FILENAME.jpg"

  # Handle different URL protocols
  if [[ "$ART_URL" == file://* ]]; then
    # Local file
    FILE_PATH=''${ART_URL#file://}
    cp "$FILE_PATH" "$OUTPUT_PATH"
  elif [[ "$ART_URL" == http://* || "$ART_URL" == https://* ]]; then
    # Remote URL
    ${pkgs.curl}/bin/curl -s "$ART_URL" -o "$OUTPUT_PATH"
  else
    echo "Unsupported URL scheme: $ART_URL"
    exit 1
  fi

  # Display the image
  if command -v ${pkgs.kitty}/bin/kitty &>/dev/null && [ -n "$KITTY_WINDOW_ID" ]; then
    # If running in kitty terminal
    ${pkgs.kitty}/bin/kitty +kitten icat --clear "$OUTPUT_PATH"
    echo "-------------------------------------------"
    echo "Album art displayed. Press any key to close window."
    read -r -n 1 -s
    ${pkgs.kitty}/bin/kitty +kitten icat --clear
    # Kill the parent process (kitty terminal window)
    # Find the parent process ID and kill it
    kill -9 $(ps -o ppid= $$)
  elif command -v ${pkgs.libnotify}/bin/notify-send &>/dev/null; then
    # Fall back to notification with image
    ${pkgs.libnotify}/bin/notify-send -i "$OUTPUT_PATH" "Now Playing" "$TITLE by $ARTIST\n$ALBUM"
  else
    echo "No suitable image viewer found. Image saved to $OUTPUT_PATH"
  fi
''
