#!/usr/bin/env bash
set -euo pipefail

# Parallel Task Executor for Claude Code
# Executes multiple tasks in parallel, separated by pipe character

# Configuration
LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/parallel-logs}"
mkdir -p "$LOG_DIR"

# Split tasks by pipe character
IFS='|' read -ra TASKS <<<"$*"

echo "🔀 Running ${#TASKS[@]} tasks in parallel..."
echo ""

for i in "${!TASKS[@]}"; do
  task="${TASKS[$i]}"
  task=$(echo "$task" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # trim

  echo "[$i] Starting: $task"

  (
    log_file="$LOG_DIR/task_$i.log"
    if npx @anthropic-ai/claude-code@latest "$task" >"$log_file" 2>&1; then
      echo "[$i] ✅ Completed: $task"
    else
      echo "[$i] ❌ Failed: $task (see $log_file)"
    fi
  ) &
done

wait

echo ""
echo "✅ All parallel tasks completed"
echo "   Logs: $LOG_DIR"
