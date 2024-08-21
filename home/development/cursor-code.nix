{pkgs, ...}:
pkgs.writeShellScriptBin "cursor" ''
  cursor_app="$(find ~/Downloads/Apps/ -maxdepth 1 -name 'cursor*.AppImage' | sort | tail -n 1)"
  if [[ -f "$cursor_app" ]]; then
      appimage-run "$cursor_app" "$@"
  else
      echo "Cursor AppImage not found or not executable in ~/Apps."
      exit 1
  fi
''
