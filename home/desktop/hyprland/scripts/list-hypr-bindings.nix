{ pkgs, ... }:

let
  terminal = "kitty";
in
pkgs.writeShellScriptBin "list-hypr-bindings" ''
  yad --width=800 --height=650 \
  --center \
  --fixed \
  --title="Hyprland Keybindings" \
  --no-buttons \
  --list \
  --column=Key: \
  --column=Description: \
  --column=Command: \
  --timeout=90 \
  --timeout-indicator=right \
  " = Windows/Super/CAPS LOCK" "Modifier Key, used for keybindings" "Doesn't really execute anything by itself." \
  " + ENTER" "Float Terminal" "${terminal}" \
  " + ALT + T" "Terminal" "${terminal}" \
  " + SPACE" "Rofi App Launcher" "rofi -show drun" \
  " + W" "Kill Focused Window" "killactive" \
  " + N" "Dunst History" "dunstctl history-pop" \
  " + SHIFT + N" "Close all Dunst Notifications" "dunctctl close-all" \
  " + E" "File Browser Yazi" "yazi" \
  " + P" "Pin Window" "pin" \
  " + SHIFT + P" "Unpin Window" "unpin" \
  " + H" "Move Window to hidden space" "spesial:hidden" \
  " + SHIFT + H" "Move Window from hidden space" "unhidden" \
  " + K" "Hyprland Kill" "hyprctl kill" \
  " + SHIFT + M" "Power Menu" "rofi powermenu" \
  " + S" "Toggle Spesial workpsace" "magic" \
  " + SHIFT + S" "Move to Spesial workspace" "magic" \
  " + L" "Lock Screen" "hyprlock" \
  " + left" "move focus left" "movefocus l" \
  " + right" "move focus right" "movefocus r" \
  " + up" "move focus up" "movefocus u" \
  " + down" "move focus down" "movefocus d" \
  " + X" "Spotify Next" "spotify next" \
  " + Z" "Spotify Previous" "spotify previous" \
  " + C" "Spotify Play/Pause" "spotify playpause" \
  " + V" "Spotify Volume Up" "spotify volume up" \
  " + SHIFT + V" "Volume Up" "volume up" \
  " + B" "Spotify Volume Down" "spotify volume down" \
  " + SHIFT + B" "Volume Down" "volume down" \
  " + SLASH" "Mute Sound" "mute" \
  " + F" "Fullscreen" "fullscreen, 1" \
  " + SHIFT + F" "True fullscreen" "fullscreen, 0" \
  " + Q" "Toogle Float" "togglefloat" \
  " + Y" "Layout Dwingle" "dwingle" \
  " + U" "Layout Master" "master" \
  " + SHIFT + U" "Orientation Cycle" "orientationcycle" \
  " + I" "Layout Next" "cyclenext" \
  " + SHIFT + I" "Layout Previous" "cycleprev" \
  " + O" "Swap With Master" "swapwithmaster" \
  " + SHIFT + O" "Focus Master" "focusmaster" \
  " + BRACKETLEFT" "Roll Next" "rollnext" \
  " + BRACKETRIGHT" "Roll Previous" "rollprev" \
  " + P" "Pseudo" "pseudo" \
  " + SHIFT + [1-0]" "Move to workspace " "movetoworkspace 1-0" \
  " + [1-0]" "Go to workspace " "workspace 1-0" \
  " + ALT + right" "Resize + 30" "resizeactive" \
  " + ALT + left" "Resize - 30" "resizeactive" \
  " + ALT + up" "Resize + 30" "resizeactive" \
  " + ALT + down" "Resize - 30" "resizeactive" \
  " + B" "Kill Swaybar" "pkill -SIGUSR1 waybar" \
  " + SHIFT + B" "Restart Swaybar" "pkill -SIGUSR2 waybar" \
  " + CTRL + right" "Switch to workspace" "workspace, r+1" \
  " + CTRL + left" "Switch to workspace" "workspace, r-1" \
  " + CTRL + down" "Switch to next empty workspace" "workspace, empty" \
  " + TAB" "Change Group Activity" "wchangegroupactive" \
  ""
''
