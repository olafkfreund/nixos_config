#!/usr/bin/env bash
# network-stability-helper.sh
# Helper script for monitoring and resolving network stability issues
# for fixing net::ERR_NETWORK_CHANGED errors in Electron applications

# Log to the systemd journal
log() {
  logger -t network-stability "$1"
}

# Monitor network interfaces for changes
monitor_interfaces() {
  log "Starting network interface monitoring"

  # Get initial state
  local previous_interfaces=$(ip -brief address show | grep -v "^lo" | sort)

  while true; do
    # Get current state
    local current_interfaces=$(ip -brief address show | grep -v "^lo" | sort)

    # Check for changes
    if [[ "$current_interfaces" != "$previous_interfaces" ]]; then
      log "Network interface change detected"
      log "Previous: $previous_interfaces"
      log "Current: $current_interfaces"

      # Update reference state
      previous_interfaces="$current_interfaces"

      # Apply stabilization measures
      stabilize_network
    fi

    # Wait before checking again
    sleep 5
  done
}

# Apply network stabilization measures
stabilize_network() {
  log "Applying network stabilization measures"

  # Wait briefly to let the network settle
  sleep 2

  # Check if systemd-resolved is running and restart if needed
  if systemctl is-active systemd-resolved &>/dev/null; then
    if ! host -W 2 example.com &>/dev/null; then
      log "DNS resolution failed, restarting systemd-resolved"
      systemctl restart systemd-resolved
    fi
  fi

  # Notify applications of stability changes (creates a file that applications can monitor)
  echo "$(date +%s)" >/run/network-stability-event
  chmod 644 /run/network-stability-event
}

# Main function
main() {
  log "Network stability helper started"

  # Create run directory if it doesn't exist
  mkdir -p /run/network-stability

  # Start monitoring in background
  monitor_interfaces &

  # Wait for signals
  wait
}

# Run main function
main "$@"
