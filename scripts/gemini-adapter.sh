#!/usr/bin/env bash
# gemini-adapter.sh - Helper for Gemini agents to interact with the system
# Usage: source scripts/gemini-adapter.sh

STATE_DIR=".gemini/state"
mkdir -p "$STATE_DIR"

# Write structured JSON state
write_state() {
  local file="$1"
  local content="$2"
  echo "$content" >"$STATE_DIR/$file"
}

# Read state
read_state() {
  local file="$1"
  if [ -f "$STATE_DIR/$file" ]; then
    cat "$STATE_DIR/$file"
  else
    echo "{}"
  fi
}

# Log for agent consumption
agent_log() {
  local level="$1"
  local message="$2"
  echo "[$level] $message"
  # Also write to a log file agents can read
  echo "$(date -Iseconds) [$level] $message" >>"$STATE_DIR/agent_activity.log"
}
