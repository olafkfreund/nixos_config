{pkgs, ...}:
pkgs.writeShellScriptBin "notify_count" ''
  notif_count="$(swaync-client -c)"
  notify-send -e -t 2000 "You have..." "''${notif_count} notifications."
''
