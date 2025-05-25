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
    ${pkgs.curl}/bin/curl -s "wttr.in/London?0" 2>/dev/null || {
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
      # Kitty terminal with custom window
      ${pkgs.kitty}/bin/kitty \
        --title "Weather - London" \
        --override font_size=12 \
        --override window_padding_width=20 \
        --override background_opacity=0.95 \
        --hold \
        bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?0" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.alacritty}/bin/alacritty &>/dev/null; then
      # Alacritty terminal
      ${pkgs.alacritty}/bin/alacritty \
        --title "Weather - London" \
        --option window.dimensions.columns=100 \
        --option window.dimensions.lines=30 \
        -e bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?0" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.wezterm}/bin/wezterm &>/dev/null; then
      # WezTerm
      ${pkgs.wezterm}/bin/wezterm \
        start \
        -- bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?0" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.foot}/bin/foot &>/dev/null; then
      # Foot terminal (Wayland)
      ${pkgs.foot}/bin/foot \
        --title="Weather - London" \
        --window-size-chars=100x30 \
        bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?0" 2>/dev/null || {
            echo "❌ Failed to fetch weather data"
            echo "Please check your internet connection"
          }
          echo ""
          echo "-------------------------------------------"
          echo "Press any key to close..."
          read -r -n 1 -s
        '
    elif command -v ${pkgs.gnome.gnome-terminal}/bin/gnome-terminal &>/dev/null; then
      # GNOME Terminal
      ${pkgs.gnome.gnome-terminal}/bin/gnome-terminal \
        --title="Weather - London" \
        --geometry=100x30 \
        --wait \
        -- bash -c '
          echo "🌤️  Weather for London"
          echo "===================="
          ${pkgs.curl}/bin/curl -s "wttr.in/London?0" 2>/dev/null || {
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
      echo "Please install one of: kitty, alacritty, wezterm, foot, or gnome-terminal"
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
