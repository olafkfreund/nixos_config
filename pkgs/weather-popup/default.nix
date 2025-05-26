{
  lib,
  pkgs,
  ...
}:
pkgs.writeShellScriptBin "weather-popup" ''
  #!/usr/bin/env bash
  # weather-popup: Shows weather information in a popup terminal

  # Function to display weather in current terminal
  show_weather_inline() {
    echo "🌤️  Weather for London"
    echo "===================="
    ${pkgs.curl}/bin/curl -s "wttr.in/London?1" 2>/dev/null || {
      echo "❌ Failed to fetch weather data"
      echo "Please check your internet connection"
      return 1
    }
    echo ""
    echo "-------------------------------------------"
    echo "Press any key to close..."
    read -r -n 1 -s
  }

  # Function to open weather in new terminal window
  open_weather_terminal() {
    # Try different terminal emulators in order of preference
    if command -v ${pkgs.kitty}/bin/kitty &>/dev/null; then
      # Kitty terminal with custom window and class
      ${pkgs.kitty}/bin/kitty \
        --title "Weather - London" \
        --class "weather-popup" \
        --override font_size=14 \
        --override window_padding_width=25 \
        --override background_opacity=0.95 \
        --override remember_window_size=no \
        --override initial_window_width=150c \
        --override initial_window_height=40c \
        --override placement_strategy=center \
        --override close_on_child_death=yes \
        bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?1" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.alacritty}/bin/alacritty &>/dev/null; then
      # Alacritty terminal with class
      ${pkgs.alacritty}/bin/alacritty \
        --title "Weather - London" \
        --class "weather-popup" \
        --option window.dimensions.columns=90 \
        --option window.dimensions.lines=35 \
        --option window.opacity=0.95 \
        -e bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?1" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.wezterm}/bin/wezterm &>/dev/null; then
      # WezTerm with class
      ${pkgs.wezterm}/bin/wezterm \
        start \
        --class "weather-popup" \
        -- bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?1" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.foot}/bin/foot &>/dev/null; then
      # Foot terminal (Wayland) with app-id
      ${pkgs.foot}/bin/foot \
        --title="Weather - London" \
        --app-id="weather-popup" \
        --window-size-chars=90x35 \
        bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?1" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    else
      echo "❌ No supported terminal emulator found"
      echo "Please install one of: kitty, alacritty, wezterm, or foot"
      exit 1
    fi
  }

  # Check if running inside a terminal session
  if [ -t 0 ] && [ -t 1 ] && [ -n "$TERM" ]; then
    # We're already in a terminal, show weather inline
    show_weather_inline
  else
    # Not in terminal or running from GUI, open new terminal window
    open_weather_terminal
  fi
''
