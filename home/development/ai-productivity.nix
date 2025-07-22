{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.development.ai-productivity;
  
  # AI-enhanced task creation script
  smartTaskAdd = pkgs.writeShellScript "smart-task-add" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Colors for beautiful output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    
    if [[ $# -eq 0 ]]; then
        echo -e "''${RED}Usage:''${NC} smart-add <natural language task description>"
        echo -e "''${CYAN}Example:''${NC} smart-add \"Review PR, update docs, deploy by Friday\""
        exit 1
    fi
    
    input_text="$*"
    
    echo -e "''${BLUE}🧠 AI is analyzing your task...''${NC}"
    
    # Use AI to parse natural language into structured tasks
    ai_prompt="Parse this natural language task description into structured Taskwarrior tasks. 
    
    Input: '$input_text'
    
    For each task, provide:
    - Description (clear, actionable)
    - Project (if mentioned or inferable)  
    - Priority (H/M/L based on urgency indicators)
    - Due date (if mentioned, use YYYY-MM-DD format)
    - Tags (relevant context tags)
    
    Format your response as JSON array of tasks:
    [
      {
        \"description\": \"task description\",
        \"project\": \"project_name\",
        \"priority\": \"H|M|L\", 
        \"due\": \"YYYY-MM-DD\",
        \"tags\": [\"tag1\", \"tag2\"]
      }
    ]
    
    Only include fields that are clearly indicated. If no due date mentioned, omit it."
    
    # Get AI analysis
    ai_response=$(ai-cli -p anthropic "$ai_prompt" 2>/dev/null || echo "[]")
    
    if [[ "$ai_response" == "[]" ]] || [[ -z "$ai_response" ]]; then
        echo -e "''${YELLOW}⚠️  AI parsing failed, creating simple task...''${NC}"
        ${pkgs.taskwarrior3}/bin/task add "$input_text"
        exit 0
    fi
    
    echo -e "''${GREEN}✨ Creating structured tasks:''${NC}"
    
    # Parse JSON and create tasks (simplified for now)
    echo "$ai_response" | ${pkgs.jq}/bin/jq -c '.[]' | while IFS= read -r task_json; do
        desc=$(echo "$task_json" | ${pkgs.jq}/bin/jq -r '.description // empty')
        project=$(echo "$task_json" | ${pkgs.jq}/bin/jq -r '.project // empty') 
        priority=$(echo "$task_json" | ${pkgs.jq}/bin/jq -r '.priority // empty')
        due=$(echo "$task_json" | ${pkgs.jq}/bin/jq -r '.due // empty')
        tags=$(echo "$task_json" | ${pkgs.jq}/bin/jq -r '.tags[]? // empty' | tr '\n' ' ')
        
        if [[ -n "$desc" ]]; then
            cmd="task add \"$desc\""
            [[ -n "$project" ]] && cmd="$cmd project:$project"
            [[ -n "$priority" ]] && cmd="$cmd priority:$priority"
            [[ -n "$due" ]] && cmd="$cmd due:$due"
            [[ -n "$tags" ]] && cmd="$cmd $tags"
            
            echo -e "''${CYAN}📝 Adding:''${NC} $desc"
            eval "$cmd"
        fi
    done
    
    echo -e "''${GREEN}✅ Tasks created successfully!''${NC}"
    echo -e "''${BLUE}📋 Your current tasks:''${NC}"
    ${pkgs.taskwarrior3}/bin/task next
  '';
  
  # AI-enhanced daily dashboard
  aiDashboard = pkgs.writeShellScript "ai-dashboard" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Colors and emojis for beautiful output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
    
    clear
    echo -e "''${BOLD}''${BLUE}╔══════════════════════════════════════════════════════════════════╗''${NC}"
    echo -e "''${BOLD}''${BLUE}║                   🚀 AI-Enhanced Daily Dashboard                 ║''${NC}"
    echo -e "''${BOLD}''${BLUE}╚══════════════════════════════════════════════════════════════════╝''${NC}"
    echo ""
    
    # Date and time
    echo -e "''${BOLD}''${CYAN}📅 $(date '+%A, %B %d, %Y')''${NC} - ''${BOLD}''${YELLOW}⏰ $(date '+%H:%M')''${NC}"
    echo ""
    
    # Task summary with beautiful formatting
    echo -e "''${BOLD}''${GREEN}📋 TASK OVERVIEW''${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Count various task types
    total_tasks=$(${pkgs.taskwarrior3}/bin/task status:pending count 2>/dev/null || echo "0")
    urgent_tasks=$(${pkgs.taskwarrior3}/bin/task status:pending urgency.over:10 count 2>/dev/null || echo "0")
    due_today=$(${pkgs.taskwarrior3}/bin/task due:today count 2>/dev/null || echo "0")
    overdue=$(${pkgs.taskwarrior3}/bin/task overdue count 2>/dev/null || echo "0")
    
    echo -e "📊 Total Tasks: ''${BOLD}$total_tasks''${NC} | 🔥 Urgent: ''${BOLD}''${RED}$urgent_tasks''${NC} | 📅 Due Today: ''${BOLD}''${YELLOW}$due_today''${NC} | ⚠️  Overdue: ''${BOLD}''${RED}$overdue''${NC}"
    echo ""
    
    # Show next tasks with priorities
    if [[ "$total_tasks" -gt 0 ]]; then
        echo -e "''${BOLD}''${PURPLE}🎯 NEXT PRIORITY TASKS''${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ${pkgs.taskwarrior3}/bin/task next limit:5 2>/dev/null || echo "No pending tasks"
        echo ""
    fi
    
    # AI Insights section
    echo -e "''${BOLD}''${CYAN}🧠 AI INSIGHTS''${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get current tasks for AI analysis
    current_tasks=$(${pkgs.taskwarrior3}/bin/task status:pending export 2>/dev/null | ${pkgs.jq}/bin/jq -c '.[0:5]' || echo "[]")
    
    if [[ "$current_tasks" != "[]" ]] && [[ -n "$current_tasks" ]]; then
        ai_prompt="Based on these pending tasks, provide 3 brief actionable insights for productivity:
        
        Tasks: $current_tasks
        
        Focus on:
        1. Priority recommendations
        2. Time management tips  
        3. Workflow optimization
        
        Keep each insight to one line, use emojis, be encouraging and practical."
        
        echo -e "''${YELLOW}💭 Analyzing your tasks...''${NC}"
        ai_insights=$(ai-cli -p anthropic "$ai_prompt" 2>/dev/null || echo "Focus on high-priority tasks first! 🎯")
        
        echo -e "''${GREEN}$ai_insights''${NC}"
    else
        echo -e "''${GREEN}🎉 No pending tasks! Great job staying on top of things!''${NC}"
    fi
    
    echo ""
    
    # Quick actions
    echo -e "''${BOLD}''${BLUE}⚡ QUICK ACTIONS''${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "🆕 smart-add \"description\"  📝 t            🏁 td <id>        🔍 ai-analyze"
    echo -e "📊 ai-summary daily          📈 ai-insights  🗂️  task projects  ⏰ tws \"work\""
    echo ""
    
    # Time tracking summary if timewarrior is active
    if command -v ${pkgs.timewarrior}/bin/timew >/dev/null 2>&1; then
        active_tracking=$(${pkgs.timewarrior}/bin/timew get dom.active 2>/dev/null || echo "0")
        if [[ "$active_tracking" == "1" ]]; then
            echo -e "''${BOLD}''${GREEN}⏱️  ACTIVE TIME TRACKING''${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ${pkgs.timewarrior}/bin/timew summary :ids
            echo ""
        fi
        
        # Today's time summary
        today_time=$(${pkgs.timewarrior}/bin/timew summary today 2>/dev/null | tail -n 1 || echo "No time tracked today")
        echo -e "''${BOLD}''${CYAN}⏲️  TODAY'S TIME: ''${today_time}''${NC}"
        echo ""
    fi
    
    echo -e "''${BOLD}''${GREEN}Ready to make today productive! 🚀''${NC}"
    echo ""
  '';
  
  # AI task analysis and suggestions
  aiAnalyze = pkgs.writeShellScript "ai-analyze" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    
    echo -e "''${BLUE}🧠 AI Task Analysis''${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get current task data
    tasks_json=$(${pkgs.taskwarrior3}/bin/task status:pending export 2>/dev/null || echo "[]")
    
    if [[ "$tasks_json" == "[]" ]]; then
        echo -e "''${GREEN}🎉 No pending tasks to analyze! You're all caught up!''${NC}"
        exit 0
    fi
    
    # AI analysis prompt
    ai_prompt="Analyze these Taskwarrior tasks and provide actionable insights:
    
    Tasks: $tasks_json
    
    Please provide:
    1. 🎯 Priority Recommendations - which tasks to focus on first and why
    2. 🚧 Potential Blockers - identify dependencies or bottlenecks  
    3. ⏱️  Time Management - estimate effort and suggest scheduling
    4. 📈 Optimization Tips - workflow improvements
    
    Be concise, use emojis, and focus on actionable advice."
    
    echo -e "''${CYAN}💭 Analyzing your task portfolio...''${NC}"
    echo ""
    
    analysis=$(ai-cli -p anthropic "$ai_prompt" 2>/dev/null || echo "Unable to analyze tasks at this time.")
    
    echo -e "''${GREEN}$analysis''${NC}"
    echo ""
    
    echo -e "''${YELLOW}💡 Quick Actions:''${NC}"
    echo "• smart-add - Add new tasks with AI parsing"
    echo "• ai-summary - Generate work summary" 
    echo "• task next - View priority queue"
    echo "• td <id> - Mark task complete"
  '';
  
  # AI work summarization
  aiSummary = pkgs.writeShellScript "ai-summary" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    GREEN='\033[0;32m'
    BLUE='\033[0;34m' 
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    
    period="''${1:-daily}"
    
    echo -e "''${BLUE}📊 AI Work Summary (''${period})''${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    case "$period" in
        "daily")
            completed_tasks=$(${pkgs.taskwarrior3}/bin/task completed end:today export 2>/dev/null || echo "[]")
            pending_tasks=$(${pkgs.taskwarrior3}/bin/task status:pending export 2>/dev/null | ${pkgs.jq}/bin/jq -c '.[0:5]' || echo "[]")
            time_frame="today"
            ;;
        "weekly") 
            completed_tasks=$(${pkgs.taskwarrior3}/bin/task completed end:week export 2>/dev/null || echo "[]")
            pending_tasks=$(${pkgs.taskwarrior3}/bin/task status:pending export 2>/dev/null | ${pkgs.jq}/bin/jq -c '.[0:10]' || echo "[]")
            time_frame="this week"
            ;;
        *)
            echo -e "''${YELLOW}Usage: ai-summary [daily|weekly]''${NC}"
            exit 1
            ;;
    esac
    
    # Get time tracking data if available
    time_summary=""
    if command -v ${pkgs.timewarrior}/bin/timew >/dev/null 2>&1; then
        case "$period" in
            "daily")
                time_summary=$(${pkgs.timewarrior}/bin/timew summary today 2>/dev/null || echo "")
                ;;
            "weekly")
                time_summary=$(${pkgs.timewarrior}/bin/timew summary week 2>/dev/null || echo "")
                ;;
        esac
    fi
    
    # AI summarization prompt
    ai_prompt="Create a professional work summary for $time_frame:
    
    Completed Tasks: $completed_tasks
    Upcoming Tasks: $pending_tasks  
    Time Tracking: $time_summary
    
    Generate a summary including:
    1. 🎯 Key Accomplishments - what was completed
    2. ⏱️  Time Investment - how time was spent
    3. 📈 Progress Made - advancement toward goals
    4. 🔮 Next Focus - priorities moving forward
    5. 💡 Insights - patterns or learnings
    
    Keep it professional but engaging. Use bullet points and emojis."
    
    echo -e "''${CYAN}🤖 Generating your work summary...''${NC}"
    echo ""
    
    summary=$(ai-cli -p anthropic "$ai_prompt" 2>/dev/null || echo "Unable to generate summary at this time.")
    
    echo -e "''${GREEN}$summary''${NC}"
    echo ""
    
    # Save summary to file
    summary_dir="$HOME/.task/summaries"
    mkdir -p "$summary_dir"
    summary_file="$summary_dir/$(date +%Y-%m-%d)-$period.md"
    
    {
        echo "# Work Summary - $(date '+%B %d, %Y') ($period)"
        echo ""
        echo "$summary"
        echo ""
        echo "---"
        echo "Generated on $(date) by AI-Enhanced Taskwarrior"
    } > "$summary_file"
    
    echo -e "''${BLUE}💾 Summary saved to: $summary_file''${NC}"
  '';

in {
  options.development.ai-productivity = {
    enable = mkEnableOption "AI-enhanced productivity tools";
    
    enhancedDashboard = mkEnableOption "AI-enhanced daily dashboard";
    
    smartTaskCreation = mkEnableOption "AI-powered natural language task creation";
    
    workSummarization = mkEnableOption "AI work summarization and reporting";
  };

  config = mkIf cfg.enable {
    # Install required packages
    home.packages = with pkgs; [
      jq  # JSON processing
      bc  # Basic calculator for time calculations
    ];

    # Install AI productivity scripts
    home.file.".local/bin/smart-add" = {
      source = smartTaskAdd;
      executable = true;
    };
    
    home.file.".local/bin/ai-dashboard" = mkIf cfg.enhancedDashboard {
      source = aiDashboard;
      executable = true;
    };
    
    home.file.".local/bin/ai-analyze" = {
      source = aiAnalyze;
      executable = true;
    };
    
    home.file.".local/bin/ai-summary" = mkIf cfg.workSummarization {
      source = aiSummary;
      executable = true;
    };

    # Shell integration
    programs.zsh.shellAliases = mkMerge [
      (mkIf cfg.smartTaskCreation {
        "smart-add" = "smart-add";
        "sa" = "smart-add";  # Quick alias
      })
      
      (mkIf cfg.enhancedDashboard {
        "dashboard" = "ai-dashboard";
        "dash" = "ai-dashboard";
        "daily" = "ai-dashboard";
      })
      
      {
        "ai-analyze" = "ai-analyze";
        "analyze" = "ai-analyze";
        "insights" = "ai-analyze";
      }
      
      (mkIf cfg.workSummarization {
        "ai-summary" = "ai-summary";
        "summary" = "ai-summary daily";
        "weekly-summary" = "ai-summary weekly";
      })
    ];

    # ZSH functions for enhanced functionality
    programs.zsh.initExtra = ''
      # AI-enhanced task functions
      ai-project() {
        if [[ $# -eq 0 ]]; then
          echo "Usage: ai-project <project description>"
          return 1
        fi
        
        echo "🧠 AI is breaking down your project..."
        ai-cli -p anthropic "Break down this project into 5-8 actionable Taskwarrior tasks with priorities and dependencies: '$*'. Format as individual task add commands I can run."
      }
      
      ai-insights() {
        echo "🔮 Generating productivity insights..."
        local completed_count=$(task completed end:week count 2>/dev/null || echo "0")
        local pending_count=$(task status:pending count 2>/dev/null || echo "0") 
        
        ai-cli -p anthropic "Based on $completed_count completed tasks this week and $pending_count pending tasks, provide 3 productivity insights and suggestions for optimization. Be encouraging and practical."
      }
      
      ai-suggest() {
        echo "💡 AI Task Suggestions..."
        local current_context=$(pwd | xargs basename)
        local git_branch=""
        
        if git rev-parse --git-dir >/dev/null 2>&1; then
          git_branch=$(git branch --show-current 2>/dev/null || echo "")
        fi
        
        ai-cli -p anthropic "I'm working in directory '$current_context'$([ -n "$git_branch" ] && echo " on git branch '$git_branch'"). Based on my current tasks: $(task next export 2>/dev/null | jq -c '.[0:3]' || echo "[]"), suggest what I should work on next. Consider context and priorities."
      }
      
      # Quick task completion with AI celebration
      smart-done() {
        if [[ $# -eq 0 ]]; then
          echo "Usage: smart-done <task_id>"
          return 1
        fi
        
        local task_desc=$(task _get $1.description 2>/dev/null || echo "")
        task done $1
        
        if [[ -n "$task_desc" ]]; then
          echo "🎉 Great work completing: $task_desc"
          ai-cli -p anthropic "Generate a brief, encouraging message for completing this task: '$task_desc'. Keep it motivational and under 20 words."
        fi
      }
    '';
  };
}