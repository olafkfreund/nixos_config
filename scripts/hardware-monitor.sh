#!/usr/bin/env bash
#
# Hardware Monitor Script for NixOS
# Monitors system logs for hardware issues and sends desktop notifications
# Supports P620 (AMD) and Razer (Intel/NVIDIA) specific hardware checks
#

set -euo pipefail

# Configuration
SCRIPT_NAME="Hardware Monitor"
LOG_FILE="/var/log/hardware-monitor.log"
STATE_FILE="/tmp/hardware-monitor-state"
CHECK_INTERVAL_MINUTES=5

# Hardware-specific patterns based on host
HOSTNAME=$(hostname)

# Common hardware issue patterns
declare -A PATTERNS=(
  # USB Issues
  ["usb_disconnect"]="usb.*disconnect"
  ["usb_power_fail"]="Cannot enable.*USB cable"
  ["usb_reset"]="USB disconnect.*new USB device"

  # Storage Issues
  ["disk_error"]="ata.*error|sd.*error|nvme.*error"
  ["smart_fail"]="SMART.*FAIL|reallocated sector"
  ["filesystem_error"]="EXT4-fs error|XFS.*error|filesystem.*corrupt"

  # Memory Issues
  ["memory_error"]="Machine Check Exception|memory.*error|EDAC.*error"
  ["oom_kill"]="Out of memory.*Killed process"

  # Network Issues
  ["network_down"]="Link is Down|carrier lost|network.*timeout"
  ["wifi_fail"]="wifi.*failed|authentication.*failed"

  # Temperature Issues
  ["thermal_throttle"]="thermal.*throttle|temperature.*critical"
  ["fan_fail"]="fan.*error|cooling.*failed"

  # Power Issues
  ["power_fail"]="power.*supply.*fail|voltage.*out of range"
  ["battery_critical"]="battery.*critical|charge.*low"
)

# Host-specific patterns
case "$HOSTNAME" in
  "p620")
    PATTERNS+=(
      ["amd_gpu_error"]="amdgpu.*error|radeon.*error|DRM.*error"
      ["rocm_fail"]="ROCm.*error|HSA.*fail"
      ["amd_thermal"]="k10temp.*error|amd.*thermal"
    )
    ;;
  "razer")
    PATTERNS+=(
      ["nvidia_error"]="nvidia.*error|NVRM.*error"
      ["intel_gpu_error"]="i915.*error|intel.*graphics.*error"
      ["optimus_fail"]="optimus.*error|gpu.*switch.*fail"
      ["laptop_thermal"]="ACPI.*thermal|laptop.*overheat"
    )
    ;;
esac

# Notification function
send_notification() {
  local severity="$1"
  local title="$2"
  local message="$3"
  local icon="$4"

  # Log the issue
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$severity] $title: $message" >>"$LOG_FILE"

  # Send desktop notification
  if command -v notify-send >/dev/null 2>&1; then
    # Determine urgency and timeout based on severity
    case "$severity" in
      "CRITICAL")
        urgency="critical"
        timeout=0 # Persistent
        ;;
      "WARNING")
        urgency="normal"
        timeout=10000 # 10 seconds
        ;;
      "INFO")
        urgency="low"
        timeout=5000 # 5 seconds
        ;;
    esac

    notify-send \
      --urgency="$urgency" \
      --expire-time="$timeout" \
      --icon="$icon" \
      --category="hardware" \
      "$title" \
      "$message"
  fi

  # Also log to systemd journal with appropriate priority
  case "$severity" in
    "CRITICAL") logger -p daemon.crit -t "$SCRIPT_NAME" "$title: $message" ;;
    "WARNING") logger -p daemon.warning -t "$SCRIPT_NAME" "$title: $message" ;;
    "INFO") logger -p daemon.info -t "$SCRIPT_NAME" "$title: $message" ;;
  esac
}

# Check for hardware issues in logs
check_hardware_issues() {
  local since_time="$1"
  local issues_found=0

  # Get recent journal entries since last check
  local journal_output
  journal_output=$(journalctl --since="$since_time" --no-pager -q 2>/dev/null || true)

  if [[ -z "$journal_output" ]]; then
    return 0
  fi

  # Check each pattern
  for pattern_name in "${!PATTERNS[@]}"; do
    local pattern="${PATTERNS[$pattern_name]}"
    local matches

    # Search for pattern in journal output (case insensitive)
    matches=$(echo "$journal_output" | grep -iE "$pattern" || true)

    if [[ -n "$matches" ]]; then
      issues_found=$((issues_found + 1))

      # Count occurrences
      local count
      count=$(echo "$matches" | wc -l)

      # Determine severity and generate notification
      case "$pattern_name" in
        *"error" | *"fail" | *"critical" | "memory_error" | "oom_kill" | "thermal_throttle")
          send_notification "CRITICAL" \
            "Hardware Issue: ${pattern_name//_/ }" \
            "$count occurrence(s) detected. Check system logs immediately!" \
            "dialog-error"
          ;;
        *"disconnect" | *"down" | *"timeout" | *"throttle")
          send_notification "WARNING" \
            "Hardware Warning: ${pattern_name//_/ }" \
            "$count occurrence(s) detected. Monitor system performance." \
            "dialog-warning"
          ;;
        *)
          send_notification "INFO" \
            "Hardware Notice: ${pattern_name//_/ }" \
            "$count occurrence(s) detected." \
            "dialog-information"
          ;;
      esac

      # Log first few matches for debugging
      echo "$matches" | head -3 >>"$LOG_FILE"
    fi
  done

  return $issues_found
}

# Check system health metrics
check_system_health() {
  local alerts=0

  # Check disk space
  while IFS= read -r line; do
    local usage filesystem
    usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    filesystem=$(echo "$line" | awk '{print $6}')

    if [[ "$usage" -gt 90 ]]; then
      send_notification "CRITICAL" \
        "Disk Space Critical" \
        "Filesystem $filesystem is ${usage}% full!" \
        "drive-harddisk"
      alerts=$((alerts + 1))
    elif [[ "$usage" -gt 80 ]]; then
      send_notification "WARNING" \
        "Disk Space Warning" \
        "Filesystem $filesystem is ${usage}% full." \
        "drive-harddisk"
      alerts=$((alerts + 1))
    fi
  done < <(df -h | grep -E '^/dev/' | grep -v '/boot')

  # Check memory usage
  local mem_usage
  mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')

  if [[ "$mem_usage" -gt 95 ]]; then
    send_notification "CRITICAL" \
      "Memory Critical" \
      "Memory usage is ${mem_usage}%! System may become unresponsive." \
      "appointment-soon"
    alerts=$((alerts + 1))
  elif [[ "$mem_usage" -gt 85 ]]; then
    send_notification "WARNING" \
      "Memory Warning" \
      "Memory usage is ${mem_usage}%." \
      "appointment-soon"
    alerts=$((alerts + 1))
  fi

  # Check load average
  local load_avg
  load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
  local cpu_cores
  cpu_cores=$(nproc)
  local load_percentage
  load_percentage=$(echo "$load_avg $cpu_cores" | awk '{printf("%.0f", $1/$2 * 100)}')

  if [[ "$load_percentage" -gt 200 ]]; then
    send_notification "CRITICAL" \
      "System Load Critical" \
      "System load is ${load_percentage}% of CPU capacity!" \
      "system-monitor"
    alerts=$((alerts + 1))
  elif [[ "$load_percentage" -gt 150 ]]; then
    send_notification "WARNING" \
      "System Load High" \
      "System load is ${load_percentage}% of CPU capacity." \
      "system-monitor"
    alerts=$((alerts + 1))
  fi

  return $alerts
}

# Check temperature sensors
check_temperatures() {
  local alerts=0

  # Check if sensors command is available
  if ! command -v sensors >/dev/null 2>&1; then
    return 0
  fi

  # Get temperature readings
  local sensor_output
  sensor_output=$(sensors 2>/dev/null || true)

  if [[ -n "$sensor_output" ]]; then
    # Look for high temperatures (>80°C for CPU, >90°C for GPU)
    while IFS= read -r line; do
      if echo "$line" | grep -qE "Core.*°C|temp.*°C|GPU.*°C"; then
        local temp
        temp=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | sed 's/°C//')
        local sensor_name
        sensor_name=$(echo "$line" | awk -F: '{print $1}' | sed 's/^[[:space:]]*//')

        if [[ -n "$temp" ]]; then
          if (($(echo "$temp > 90" | bc -l))); then
            send_notification "CRITICAL" \
              "Temperature Critical" \
              "$sensor_name: ${temp}°C - System may throttle or shutdown!" \
              "temperature-high"
            alerts=$((alerts + 1))
          elif (($(echo "$temp > 80" | bc -l))); then
            send_notification "WARNING" \
              "Temperature High" \
              "$sensor_name: ${temp}°C - Monitor system cooling." \
              "temperature-high"
            alerts=$((alerts + 1))
          fi
        fi
      fi
    done <<<"$sensor_output"
  fi

  return $alerts
}

# Main monitoring function
main() {
  # Ensure log directory exists
  sudo mkdir -p "$(dirname "$LOG_FILE")"
  sudo touch "$LOG_FILE"

  # Determine time since last check
  local since_time="5 minutes ago"
  if [[ -f "$STATE_FILE" ]]; then
    local last_check
    last_check=$(cat "$STATE_FILE" 2>/dev/null || echo "5 minutes ago")
    since_time="$last_check"
  fi

  # Update state file with current time
  date '+%Y-%m-%d %H:%M:%S' >"$STATE_FILE"

  # Perform checks
  local total_issues=0

  echo "$(date '+%Y-%m-%d %H:%M:%S') Starting hardware monitoring check..." >>"$LOG_FILE"

  # Check for hardware issues in logs
  if check_hardware_issues "$since_time"; then
    total_issues=$((total_issues + $?))
  fi

  # Check system health metrics
  if check_system_health; then
    total_issues=$((total_issues + $?))
  fi

  # Check temperatures
  if check_temperatures; then
    total_issues=$((total_issues + $?))
  fi

  # Send summary if issues found
  if [[ "$total_issues" -gt 0 ]]; then
    send_notification "WARNING" \
      "Hardware Monitor Summary" \
      "$total_issues hardware issue(s) detected. Check log: $LOG_FILE" \
      "dialog-warning"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Found $total_issues total issues" >>"$LOG_FILE"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') No hardware issues detected" >>"$LOG_FILE"
  fi
}

# Check if running as daemon or one-shot
if [[ "${1:-}" == "--daemon" ]]; then
  # Daemon mode - run continuously
  echo "$(date '+%Y-%m-%d %H:%M:%S') Starting hardware monitor daemon..." >>"$LOG_FILE"

  while true; do
    main
    sleep $((CHECK_INTERVAL_MINUTES * 60))
  done
else
  # One-shot mode
  main
fi
