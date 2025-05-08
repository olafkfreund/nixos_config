{
  lib,
  pkgs,
  ...
}: {
  rofi-websearch = pkgs.writeShellScriptBin "rofi-websearch" ''
    #!/usr/bin/env bash

    # Define search engines with corresponding icons and URLs
    declare -A ENGINES
    ENGINES=(
      ["Google"]="https://www.google.com/search?q="
      ["DuckDuckGo"]="https://duckduckgo.com/?q="
      ["GitHub"]="https://github.com/search?q="
      ["StackOverflow"]="https://stackoverflow.com/search?q="
      ["NixOS Wiki"]="https://nixos.wiki/index.php?search="
      ["NixOS Packages"]="https://search.nixos.org/packages?query="
      ["NixOS Options"]="https://search.nixos.org/options?query="
      ["Arch Wiki"]="https://wiki.archlinux.org/index.php?search="
      ["YouTube"]="https://www.youtube.com/results?search_query="
      ["Reddit"]="https://www.reddit.com/search/?q="
      ["Wikipedia"]="https://en.wikipedia.org/w/index.php?search="
      ["Maps"]="https://www.openstreetmap.org/search?query="
    )

    # Icons for each search engine
    declare -A ICONS
    ICONS=(
      ["Google"]="󰊭"
      ["DuckDuckGo"]=""
      ["GitHub"]=""
      ["StackOverflow"]=""
      ["NixOS Wiki"]="󱄅"
      ["NixOS Packages"]="󰮱"
      ["NixOS Options"]="󰏗"
      ["Arch Wiki"]=""
      ["YouTube"]=""
      ["Reddit"]=""
      ["Wikipedia"]=""
      ["Maps"]=""
    )

    # Generate launcher menu
    gen_launcher_menu() {
      for engine in "''${!ENGINES[@]}"; do
        echo "''${ICONS[$engine]} $engine"
      done
    }

    # Handle URL opening
    handle_url() {
      local engine=$1
      local query=$2
      local url="''${ENGINES[$engine]}$query"

      # URL-encode the query
      url=$(echo "$url" | sed 's/ /%20/g')

      # Open in the default browser
      xdg-open "$url" &>/dev/null &
      exit 0
    }

    # Main execution flow
    if [ -z "$*" ]; then
      # No arguments - display the engine selection menu
      gen_launcher_menu
    elif [[ "$1" == *" "* ]]; then
      # If input has a space, first part is the engine and rest is query
      engine=$(echo "$1" | cut -d' ' -f1)
      # Strip the icon if present
      engine=$(echo "$engine" | sed 's/^[^ ]* //')
      query=$(echo "$1" | cut -d' ' -f2-)

      if [[ -n "''${ENGINES[$engine]}" ]]; then
        handle_url "$engine" "$query"
      else
        echo "Invalid search engine: $engine"
        exit 1
      fi
    else
      # If only engine is selected, prompt for search query
      for engine in "''${!ENGINES[@]}"; do
        if [[ "$engine" == *"$1"* ]] || [[ "''${ICONS[$engine]} $engine" == *"$1"* ]]; then
          echo "Enter search query for $engine:"
          exit 0
        fi
      done

      # If not matching an engine, assume it's a query for the default engine
      echo "Google"
      echo "DuckDuckGo"
      echo "GitHub"
      echo "NixOS Packages"
      echo "YouTube"
      echo "Wikipedia"
    fi
  '';
}
