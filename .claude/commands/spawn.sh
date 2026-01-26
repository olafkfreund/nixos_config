#!/usr/bin/env bash
set -euo pipefail

# Spawn Background Agent for Claude Code
# Spawns a new Claude Code agent in the background for a specific task

# Configuration
LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/spawn-logs}"
mkdir -p "$LOG_DIR"

TASK="$*"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/spawn_${TIMESTAMP}.log"

echo "🚀 Spawning new agent for: $TASK"
echo "   Log: $LOG_FILE"

npx @anthropic-ai/claude-code@latest "$TASK" >"$LOG_FILE" 2>&1 &

SPAWN_PID=$!
echo "   PID: $SPAWN_PID"
echo ""
echo "Running in background. Check progress:"
echo "  tail -f $LOG_FILE"
echo ""
echo "To stop:"
echo "  kill $SPAWN_PID"
