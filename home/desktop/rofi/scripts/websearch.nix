{ pkgs, ... }:
pkgs.writeShellScriptBin "rwebsearch" ''
  declare -A URLS

  URLS=(
    # General search engines
    ["google"]="https://www.google.com/search?q="
    ["duckduckgo"]="https://www.duckduckgo.com/?q="

    # NixOS specific resources
    ["nixos-pkgs"]="https://search.nixos.org/packages?query="
    ["nixos-opts"]="https://search.nixos.org/options?query="
    ["nixos-wiki"]="https://nixos.wiki/index.php?search="
    ["nixpkgs"]="https://github.com/NixOS/nixpkgs/search?q="

    # GitHub resources
    ["github"]="https://github.com/search?q="
    ["gh-issues"]="https://github.com/search?type=issues&q="

    # Development resources
    ["stackoverflow"]="https://stackoverflow.com/search?q="
    ["mdn"]="https://developer.mozilla.org/en-US/search?q="

    # Linux resources
    ["arch-wiki"]="https://wiki.archlinux.org/index.php?search="
    ["man"]="https://man.archlinux.org/search?q="

    # Media
    ["youtube"]="https://www.youtube.com/results?search_query="
    ["reddit"]="https://www.reddit.com/search/?q="
  )

  # List for rofi
  gen_list() {
      for i in "''${!URLS[@]}"
      do
        echo "$i"
      done
  }

  main() {
    # Pass the list to rofi
    platform=$( (gen_list) | rofi -dmenu -matching fuzzy -no-custom -location 0 -p "Search > " )

    if [[ -n "$platform" ]]; then
      query=$( (echo ) | rofi -dmenu -matching fuzzy -location 0 -p "Query > " )

      if [[ -n "$query" ]]; then
        # URL-encode spaces
        query=$(echo "$query" | sed 's/ /%20/g')
        url=''${URLS[$platform]}$query
        ${pkgs.xdg-utils}/bin/xdg-open "$url"
      else
        exit
      fi
    else
      exit
    fi
  }

  main
''
