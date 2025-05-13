#!/usr/bin/env bash
# network-monitor.sh - Script to monitor network drops
# Author: olafkfreund
# Date: $(date +%Y-%m-%d)

LOG_FILE="/var/log/network-monitor.log"
INTERFACE="$(ip route | grep default | awk '{print $5}')"

log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_interface() {
  if [ -z "$INTERFACE" ]; then
    log_message "No default interface found. Using fallback method."
    INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n 1)
    if [ -z "$INTERFACE" ]; then
      log_message "ERROR: Could not detect network interface."
      exit 1
    fi
  fi
  log_message "Monitoring interface: $INTERFACE"
}

# Initialize counters
get_initial_counts() {
  PREV_RX_DROPS=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_dropped 2>/dev/null || echo 0)
  PREV_TX_DROPS=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_dropped 2>/dev/null || echo 0)
  PREV_RX_ERRORS=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_errors 2>/dev/null || echo 0)
  PREV_TX_ERRORS=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_errors 2>/dev/null || echo 0)
  log_message "Initial counts - RX drops: $PREV_RX_DROPS, TX drops: $PREV_TX_DROPS, RX errors: $PREV_RX_ERRORS, TX errors: $PREV_TX_ERRORS"
}

monitor_network() {
  while true; do
    # Get current counts
    CURR_RX_DROPS=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_dropped 2>/dev/null || echo 0)
    CURR_TX_DROPS=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_dropped 2>/dev/null || echo 0)
    CURR_RX_ERRORS=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_errors 2>/dev/null || echo 0)
    CURR_TX_ERRORS=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_errors 2>/dev/null || echo 0)
    
    # Calculate differences
    RX_DROPS_DIFF=$((CURR_RX_DROPS - PREV_RX_DROPS))
    TX_DROPS_DIFF=$((CURR_TX_DROPS - PREV_TX_DROPS))
    RX_ERRORS_DIFF=$((CURR_RX_ERRORS - PREV_RX_ERRORS))
    TX_ERRORS_DIFF=$((CURR_TX_ERRORS - PREV_TX_ERRORS))
    
    # Log if there are new drops or errors
    if [ $RX_DROPS_DIFF -gt 0 ] || [ $TX_DROPS_DIFF -gt 0 ] || [ $RX_ERRORS_DIFF -gt 0 ] || [ $TX_ERRORS_DIFF -gt 0 ]; then
      log_message "ALERT: Network issues detected!"
      [ $RX_DROPS_DIFF -gt 0 ] && log_message "New RX drops: $RX_DROPS_DIFF (Total: $CURR_RX_DROPS)"
      [ $TX_DROPS_DIFF -gt 0 ] && log_message "New TX drops: $TX_DROPS_DIFF (Total: $CURR_TX_DROPS)"
      [ $RX_ERRORS_DIFF -gt 0 ] && log_message "New RX errors: $RX_ERRORS_DIFF (Total: $CURR_RX_ERRORS)"
      [ $TX_ERRORS_DIFF -gt 0 ] && log_message "New TX errors: $TX_ERRORS_DIFF (Total: $CURR_TX_ERRORS)"
      
      # Run diagnostic commands on issues
      log_message "--- Network diagnostic info ---"
      ping -c 3 8.8.8.8 >> "$LOG_FILE" 2>&1
      traceroute -n -w 1 -q 1 8.8.8.8 >> "$LOG_FILE" 2>&1
      netstat -s | grep -i "drop\|error\|fail\|timeout" >> "$LOG_FILE" 2>&1
      log_message "--- End diagnostic info ---"
    fi
    
    # Update previous counts
    PREV_RX_DROPS=$CURR_RX_DROPS
    PREV_TX_DROPS=$CURR_TX_DROPS
    PREV_RX_ERRORS=$CURR_RX_ERRORS
    PREV_TX_ERRORS=$CURR_TX_ERRORS
    
    # Sleep for 60 seconds
    sleep 60
  done
}

main() {
  log_message "Starting network monitor"
  check_interface
  get_initial_counts
  monitor_network
}

main