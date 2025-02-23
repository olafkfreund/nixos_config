{pkgs, ...}:
pkgs.writeShellScriptBin "connections" ''
  ss -tulpn 2>/dev/null \
    | grep -v -E '127\.0\.0\.1|::1' \
    | tail -n +2 \
    | awk '
  BEGIN {
    printf "%-12s %-30s %-15s\n", "Service", "Address:Port", "Process"
  }
  {
    port=$5
    process=$7
    symbol="󰙞 Other"
    if (port ~ /:80$|:443$/) {
      symbol="󰖟 Web "
    } else if (port ~ /:22$/) {
      symbol="󰛳 SSH "
    } else if (process ~ /spotify/) {
      symbol="󰓇 Spotify"
    } else if (process ~ /kdeconnect/) {
      symbol="󰍜 KDEConnect"
    } else if (process ~ /steam/) {
      symbol="󰓓 Steam"
    } else if (process ~ /chrome/) {
      symbol="󰍾 Chrome"
    }
    sub(/.*pid=/, "󰍹 pid=", process)
    sub(/,fd=.*/, "", process)
    printf "%-12s %-30s %-15s\n", symbol, port, process
  }' \
    | rofi -theme-str "configuration {
    show-icons: true;
  }
  window {
    location: south east;
    x-offset: -80;
    y-offset: 2;
    width: 1000px;
    height: 1000px;
  }
  listview {
    columns: 1;
  }
  inputbar {
    enabled: false;
  }" -dmenu -p "Connections"
''
