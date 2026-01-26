#!/usr/bin/env bash
set -euo pipefail

# Parallel Subtask Executor for Claude Code
# Breaks down a task into independent subtasks and executes them in parallel

# Configuration
MAX_PARALLEL=${CLAUDE_MAX_PARALLEL:-3}
WORK_DIR="${CLAUDE_WORK_DIR:-$HOME/.claude/subtasks}"
LOG_DIR="$WORK_DIR/logs"

# Initialize
mkdir -p "$WORK_DIR" "$LOG_DIR"

# Parse the task from stdin or args
MAIN_TASK="${*:-$(cat)}"

echo "🎯 Main Task: $MAIN_TASK"
echo ""

# Create task breakdown prompt
BREAKDOWN_PROMPT=$(
  cat <<EOF
Analyze this task and break it down into 3-5 independent subtasks:

Task: $MAIN_TASK

Requirements:
1. Each subtask should be independent and parallelizable
2. Identify any dependencies
3. Output as simple list, one per line
4. Format: <number>. <clear task description>

Output only the numbered list, nothing else.
EOF
)

# Get subtask breakdown
echo "📋 Breaking down into subtasks..."
SUBTASKS=$(npx @anthropic-ai/claude-code@latest --task "$BREAKDOWN_PROMPT" 2>/dev/null | grep -E '^[0-9]+\.')

echo ""
echo "Subtasks identified:"
echo "$SUBTASKS"
echo ""

# Create task files
echo "$SUBTASKS" | while IFS= read -r task; do
  task_num=$(echo "$task" | cut -d'.' -f1)
  task_desc=$(echo "$task" | cut -d'.' -f2- | sed 's/^ *//')
  echo "$task_desc" >"$WORK_DIR/task_${task_num}.txt"
done

# Execute in parallel
echo "🚀 Executing subtasks in parallel (max $MAX_PARALLEL at a time)..."
echo ""

run_subtask() {
  local task_file="$1"
  local task_num=$(basename "$task_file" .txt | sed 's/task_//')
  local task_desc=$(cat "$task_file")
  local log_file="$LOG_DIR/task_${task_num}.log"

  echo "[Task $task_num] Starting: $task_desc"

  if npx @anthropic-ai/claude-code@latest "$task_desc" >"$log_file" 2>&1; then
    echo "[Task $task_num] ✅ Completed"
    echo "success" >"$WORK_DIR/task_${task_num}.status"
  else
    echo "[Task $task_num] ❌ Failed (see $log_file)"
    echo "failed" >"$WORK_DIR/task_${task_num}.status"
  fi
}

export -f run_subtask
export WORK_DIR LOG_DIR

# Use GNU parallel if available, otherwise fall back to simple backgrounding
if command -v parallel &>/dev/null; then
  find "$WORK_DIR" -name "task_*.txt" \
    | parallel -j "$MAX_PARALLEL" --bar run_subtask
else
  for task_file in "$WORK_DIR"/task_*.txt; do
    run_subtask "$task_file" &

    # Simple rate limiting
    active=$(jobs -r | wc -l)
    while [ "$active" -ge "$MAX_PARALLEL" ]; do
      sleep 1
      active=$(jobs -r | wc -l)
    done
  done
  wait
fi

# Summary
echo ""
echo "📊 Summary:"
success=$(grep -l "success" "$WORK_DIR"/*.status 2>/dev/null | wc -l)
failed=$(grep -l "failed" "$WORK_DIR"/*.status 2>/dev/null | wc -l)
total=$((success + failed))

echo "  ✅ Succeeded: $success/$total"
echo "  ❌ Failed: $failed/$total"
echo ""
echo "  Logs: $LOG_DIR"
