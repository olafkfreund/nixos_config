{pkgs, ...}:
pkgs.writeShellScriptBin "search_web" ''
  # Define terminal and colors for better readability
  TERMINAL="foot"

  # Launch foot terminal with ddgr search
  $TERMINAL -e bash -c "
      echo -e '\033[1;33mDuckDuckGo Search in Terminal\033[0m'
      echo -e '\033[0;36mEnter your search query below and press Enter.\033[0m'
      echo -e '\033[0;36mNavigation: Arrow keys, Enter to open, q to quit, p to toggle preview\033[0m'
      echo '----------------------------------------'

      # Read the search query from user
      read -p 'Search: ' query

      # If query is not empty, perform the search
      if [ -n \"\$query\" ]; then
          # Execute ddgr with preview mode
          ddgr --np --colors bjdxxy \"\$query\"
      else
          echo 'Search query cannot be empty!'
          sleep 2
      fi

      # Keep terminal open after search is complete
      echo -e '\n\033[1;33mSearch complete. Press any key to exit.\033[0m'
      read -n 1
  "
''
