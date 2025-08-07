{ pkgs, ... }:
pkgs.writeShellScriptBin "search_web" ''
  # Launch the search script inside foot terminal
  exec foot -a web-search -e ${pkgs.writeShellScript "search_web" ''
    # Colors for better readability
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    echo -e "''${YELLOW}Web Search in Terminal''${NC}"
    echo -e "''${CYAN}Enter your search query below and press Enter.''${NC}"
    echo -e "''${CYAN}Navigation: Arrow keys, Enter to open, q to quit, p to toggle preview''${NC}"
    echo '----------------------------------------'


    export BROWSER="xdg-open"

    # Read the search query from user
    read -p 'Search: ' query

    # If query is not empty, perform the search
    if [ -n "$query" ]; then
        # Execute ddgr with enhanced options for better preview handling
        ${pkgs.ddgr}/bin/ddgr --expand --gb --colors bjdxxy "$query"
    else
        echo 'Search query cannot be empty!'
        sleep 2
    fi

    echo -e "\n''${YELLOW}Search complete. Press any key to exit.''${NC}"
    read -n 1
  ''}
''
