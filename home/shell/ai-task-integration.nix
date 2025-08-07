{ lib, ... }:

with lib;

{
  # Enhanced ZSH configuration for AI-integrated task management
  programs.zsh.initExtra = ''
    # AI-Enhanced Task Management Functions

    # Quick AI-powered task creation with context awareness
    smart-task() {
      if [[ $# -eq 0 ]]; then
        echo "Usage: smart-task <natural description>"
        echo "Example: smart-task 'review code, update docs, deploy by Friday'"
        return 1
      fi

      # Get current context
      local current_dir=$(pwd | xargs basename)
      local git_context=""
      local time_context=$(date +%H)

      if git rev-parse --git-dir >/dev/null 2>&1; then
        git_context="in git repository $(git remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git//' || echo $(git branch --show-current))"
      fi

      # Enhanced context-aware prompt
      local context_prompt="Current context: Working in '$current_dir' $git_context at $(date '+%A %H:%M'). "

      echo "🧠 Creating AI-enhanced tasks with context..."
      ai-cli -p anthropic "''${context_prompt}Parse this task description into structured Taskwarrior commands: '$*'. Consider the working context and time of day for appropriate prioritization and tagging."
    }

    # AI-powered task prioritization
    ai-prioritize() {
      echo "🎯 AI Task Prioritization Analysis..."

      local task_data=$(task status:pending export 2>/dev/null | jq -c '.[0:10]' || echo "[]")

      if [[ "$task_data" == "[]" ]]; then
        echo "✨ No pending tasks to prioritize! You're all caught up!"
        return 0
      fi

      local time_context=$(date '+%A at %H:%M')
      local ai_prompt="Analyze these tasks and suggest a prioritized order for today ($time_context):

      Tasks: $task_data

      Consider:
      - Due dates and urgency
      - Task dependencies
      - Estimated effort vs available time
      - Energy levels typical for this time
      - Context switching costs

      Provide a numbered priority list with brief explanations."

      ai-cli -p anthropic "$ai_prompt"
    }

    # AI task completion celebration and insights
    smart-complete() {
      if [[ $# -eq 0 ]]; then
        echo "Usage: smart-complete <task_id>"
        return 1
      fi

      local task_id=$1
      local task_desc=$(task _get $task_id.description 2>/dev/null || echo "")
      local task_project=$(task _get $task_id.project 2>/dev/null || echo "")

      # Complete the task
      task done $task_id

      if [[ -n "$task_desc" ]]; then
        echo "🎉 Task completed: $task_desc"

        # Get AI celebration and next suggestion
        local ai_prompt="I just completed this task: '$task_desc'$([ -n "$task_project" ] && echo " (project: $task_project)").

        Provide:
        1. A brief encouraging celebration message (1 line)
        2. A suggestion for what to work on next based on momentum and context

        Keep it motivational and actionable!"

        ai-cli -p anthropic "$ai_prompt" 2>/dev/null || echo "Great work! Keep the momentum going! 🚀"
      fi
    }

    # AI-powered context switching
    ai-context() {
      local mode="''${1:-suggest}"

      case "$mode" in
        "suggest")
          echo "🔄 AI Context Analysis..."

          local current_dir=$(basename $(pwd))
          local git_branch=""
          local pending_tasks=$(task status:pending export 2>/dev/null | jq -c '.[0:5]' || echo "[]")

          if git rev-parse --git-dir >/dev/null 2>&1; then
            git_branch=$(git branch --show-current 2>/dev/null || echo "")
          fi

          local context_info="Working in: $current_dir$([ -n "$git_branch" ] && echo " (branch: $git_branch)"), Time: $(date '+%A %H:%M')"

          ai-cli -p anthropic "Based on my current context ($context_info) and pending tasks: $pending_tasks, suggest the most appropriate work context or focus area. Consider energy levels, task types, and workflow efficiency."
          ;;

        "work")
          task context work
          echo "🏢 Switched to work context"
          task next limit:5
          ;;

        "personal")
          task context personal
          echo "🏠 Switched to personal context"
          task next limit:5
          ;;

        "clear")
          task context none
          echo "🌐 Cleared context filters"
          task next limit:5
          ;;

        *)
          echo "Usage: ai-context [suggest|work|personal|clear]"
          echo "  suggest  - AI suggests best context for current situation"
          echo "  work     - Switch to work context"
          echo "  personal - Switch to personal context"
          echo "  clear    - Clear all context filters"
          ;;
      esac
    }

    # AI-powered weekly review and planning
    ai-review() {
      local period="''${1:-week}"

      echo "📊 AI-Powered $period Review & Planning..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      case "$period" in
        "week")
          local completed=$(task completed end:week export 2>/dev/null || echo "[]")
          local pending=$(task status:pending export 2>/dev/null | jq -c '.[0:15]' || echo "[]")

          local ai_prompt="Conduct a weekly review based on:

          Completed this week: $completed
          Pending tasks: $pending

          Provide:
          1. 🎯 Week Highlights - key accomplishments
          2. 📈 Progress Analysis - patterns and trends
          3. 🔍 Areas for Improvement - productivity insights
          4. 🚀 Next Week Focus - recommended priorities
          5. 💡 Productivity Tips - personalized suggestions

          Be encouraging, specific, and actionable."

          ai-cli -p anthropic "$ai_prompt"
          ;;

        "day")
          ai-summary daily
          ;;

        *)
          echo "Usage: ai-review [week|day]"
          ;;
      esac
    }

    # AI-powered project breakdown
    ai-breakdown() {
      if [[ $# -eq 0 ]]; then
        echo "Usage: ai-breakdown <project_description>"
        echo "Example: ai-breakdown 'Build REST API for user management'"
        return 1
      fi

      local project_desc="$*"

      echo "🏗️  AI Project Breakdown: $project_desc"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      local ai_prompt="Break down this project into actionable Taskwarrior tasks: '$project_desc'

      Create a comprehensive project plan with:
      1. 5-10 specific, actionable tasks
      2. Logical dependencies between tasks
      3. Estimated effort (S/M/L/XL)
      4. Suggested priorities
      5. Potential risks or blockers to consider

      Format as Taskwarrior commands I can run, with explanations.
      Consider modern development practices and realistic time estimates."

      echo "💭 Analyzing project requirements..."
      ai-cli -p anthropic "$ai_prompt"

      echo ""
      echo "💡 Run the suggested commands to create your project tasks!"
      echo "   Then use 'task project:PROJECT_NAME list' to view them"
    }

    # AI-powered productivity metrics and insights
    ai-metrics() {
      echo "📊 AI Productivity Metrics & Insights"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      # Gather metrics
      local completed_today=$(task completed end:today count 2>/dev/null || echo "0")
      local completed_week=$(task completed end:week count 2>/dev/null || echo "0")
      local pending_total=$(task status:pending count 2>/dev/null || echo "0")
      local overdue=$(task overdue count 2>/dev/null || echo "0")

      # Time tracking data
      local time_today=""
      if command -v timew >/dev/null 2>&1; then
        time_today=$(timew summary today 2>/dev/null | tail -1 || echo "No time tracked")
      fi

      echo "📈 Current Metrics:"
      echo "   Today: $completed_today completed | $pending_total pending | $overdue overdue"
      echo "   This week: $completed_week completed"
      echo "   Time today: $time_today"
      echo ""

      # AI analysis
      local ai_prompt="Analyze these productivity metrics and provide insights:

      - Completed today: $completed_today tasks
      - Completed this week: $completed_week tasks
      - Pending tasks: $pending_total
      - Overdue tasks: $overdue
      - Time tracked today: $time_today
      - Current time: $(date '+%A %H:%M')

      Provide:
      1. 📊 Performance Assessment - how am I doing?
      2. 🎯 Optimization Suggestions - specific improvements
      3. ⚡ Energy Management - when to work on what
      4. 🔮 Predictions - projected completion rates

      Be data-driven, encouraging, and actionable."

      echo "🧠 Generating AI insights..."
      ai-cli -p anthropic "$ai_prompt"
    }

    # AI-powered task search and filtering
    ai-find() {
      if [[ $# -eq 0 ]]; then
        echo "Usage: ai-find <search_description>"
        echo "Example: ai-find 'tasks related to documentation'"
        return 1
      fi

      local search_query="$*"
      local all_tasks=$(task export 2>/dev/null || echo "[]")

      echo "🔍 AI-Powered Task Search: $search_query"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      local ai_prompt="Help me find tasks matching this search: '$search_query'

      Available tasks: $all_tasks

      Return:
      1. Matching task IDs and descriptions
      2. Reasoning for why they match
      3. Suggested Taskwarrior filter command to find similar tasks

      Focus on semantic meaning, not just keyword matching."

      echo "🧠 Analyzing task database..."
      ai-cli -p anthropic "$ai_prompt"
    }

    # Enhanced productivity aliases using AI functions
    alias smt='smart-task'
    alias sc='smart-complete'
    alias ap='ai-prioritize'
    alias ac='ai-context'
    alias ar='ai-review'
    alias ab='ai-breakdown'
    alias am='ai-metrics'
    alias af='ai-find'

    # Quick AI task assistant
    alias ai-task='ai-cli -p anthropic'
    alias task-ai='ai-task'

    # Enhanced existing aliases with AI integration
    alias daily='ai-dashboard'
    alias analyze='ai-analyze'
    alias insights='ai-metrics'
    alias smart-done='smart-complete'

    # Productivity workflow aliases
    alias focus='ai-context suggest'
    alias review='ai-review week'
    alias plan='ai-breakdown'
    alias metrics='ai-metrics'
    alias find-task='ai-find'

    # Morning and evening routines
    morning() {
      echo "🌅 Good morning! Let's start the day productively..."
      ai-dashboard
      echo ""
      echo "🎯 AI suggests focusing on:"
      ai-context suggest
    }

    evening() {
      echo "🌅 Evening review..."
      ai-summary daily
      echo ""
      echo "📋 Planning for tomorrow:"
      ai-context suggest
    }
  '';
}
