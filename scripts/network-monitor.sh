#!/usr/bin/env bash
# Network stability monitoring script
# This script monitors network interfaces and connection stability
# to help diagnose issues like "net::ERR_NETWORK_CHANGED" errors

# Set up logging
LOG_FILE="${HOME}/network-monitor.log"
MAX_LOG_SIZE_MB=10

# Function to log with timestamps
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to rotate logs if they get too large
rotate_logs() {
  local size_in_bytes=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  local size_in_mb=$((size_in_bytes / 1048576))

  if [ "$size_in_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    log "Log file rotated due to size (${size_in_mb}MB)"
  fi
}

# Function to check DNS resolution
check_dns() {
  for domain in "cloudflare.com" "google.com" "nixos.org"; do
    if ! host -W 2 "$domain" >/dev/null 2>&1; then
      log "DNS resolution failed for $domain"
      return 1
    fi
  done
  return 0
}

# Get current network information
get_network_info() {
  log "--- Network Interfaces ---"
  ip -brief addr show | grep -v "^lo" | while read line; do
    log "$line"
  done

  log "--- Default Routes ---"
  ip route show default | while read line; do
    log "$line"
  done

  log "--- DNS Servers ---"
  grep nameserver /etc/resolv.conf | while read line; do
    log "$line"
  done

  # Check for systemd-resolved
  if systemctl is-active systemd-resolved >/dev/null 2>&1; then
    log "--- systemd-resolved Status ---"
    resolvectl status | grep "DNS Server" | while read line; do
      log "$line"
    done
  fi
}

# Monitor network changes
monitor_network() {
  log "Starting network stability monitor"
  get_network_info

  # Store initial interface and route info
  local prev_interfaces=$(ip -brief addr show | grep -v "^lo" | sort)
  local prev_routes=$(ip route show default | sort)

  while true; do
    # Check for interface changes
    local current_interfaces=$(ip -brief addr show | grep -v "^lo" | sort)
    if [[ "$current_interfaces" != "$prev_interfaces" ]]; then
      log "Network interface change detected:"
      log "Before:"
      echo "$prev_interfaces" | while read line; do log "  $line"; done
      log "After:"
      echo "$current_interfaces" | while read line; do log "  $line"; done
      prev_interfaces="$current_interfaces"
    fi

    # Check for route changes
    local current_routes=$(ip route show default | sort)
    if [[ "$current_routes" != "$prev_routes" ]]; then
      log "Default route change detected:"
      log "Before:"
      echo "$prev_routes" | while read line; do log "  $line"; done
      log "After:"
      echo "$current_routes" | while read line; do log "  $line"; done
      prev_routes="$current_routes"
    fi

    # Check DNS resolution
    if ! check_dns; then
      log "DNS resolution issues detected"
    fi

    # Rotate logs if needed
    rotate_logs

    # Wait before checking again
    sleep 10
  done
}

# Run the monitor
monitor_network
