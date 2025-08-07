# Enhanced Project Management and Productivity Tools
# Note-taking, task management, time tracking, and collaboration tools
{ pkgs
, lib
, ...
}:
with lib;
let
  # Productivity configuration
  cfg = {
    # Note-taking and knowledge management
    notes = {
      obsidian = true; # Knowledge management
      logseq = false; # Block-based notes
      zettlr = false; # Academic writing
      notable = false; # Markdown notes
    };

    # Task and project management
    tasks = {
      # CLI task management
      taskwarrior = true; # Advanced task management
      todo_txt = false; # Simple todo.txt format

      # Time tracking
      timewarrior = true; # Time tracking companion to taskwarrior
      toggl_cli = false; # Toggl time tracking
    };

    # Communication and collaboration
    communication = {
      # Chat and messaging
      slack = true; # Team communication
      discord = true; # Community communication
      telegram = true; # Personal messaging

      # Email
      thunderbird = true; # Email client
      mailutils = false; # Command-line email tools
    };

    # Documentation and writing
    writing = {
      # Document editors
      libreoffice = false; # Office suite

      # Writing tools
      aspell = true; # Spell checker
      languagetool = false; # Grammar checker

      # Presentation tools
      slides = false; # Terminal presentations
    };

    # File management and organization
    files = {
      # File managers
      ranger = true; # Terminal file manager
      nnn = false; # Lightweight file manager

      # File utilities
      fzf = true; # Fuzzy finder
      fd = true; # Modern find replacement
      ripgrep = true; # Modern grep replacement
      bat = true; # Modern cat replacement
      exa = true; # Modern ls replacement

      # Archive tools
      unzip = true; # ZIP extraction
      p7zip = true; # 7z support
      unrar = true; # RAR support
    };

    # Productivity automation
    automation = {
      # Scripting and automation
      expect = false; # Automation scripting

      # Clipboard management
      clipboard = true; # Enhanced clipboard tools

      # Screen capture  
      flameshot = false; # Screenshot tool (handled by desktop module)
      asciinema = true; # Terminal recording
    };

    # Calendar and scheduling
    calendar = {
      calcurse = false; # Terminal calendar
      khal = false; # CLI calendar
    };
  };

  # Package collections based on configuration
  notesPackages = with pkgs; flatten [
    (optional cfg.notes.obsidian obsidian)
    (optional cfg.notes.logseq logseq)
    (optional cfg.notes.zettlr zettlr)
    (optional cfg.notes.notable notable)
  ];

  tasksPackages = with pkgs; flatten [
    (optional cfg.tasks.taskwarrior taskwarrior3)
    (optional cfg.tasks.todo_txt todo-txt-cli)
    (optional cfg.tasks.timewarrior timewarrior)
    (optional cfg.tasks.toggl_cli toggl-track)
  ];

  communicationPackages = with pkgs; flatten [
    (optional cfg.communication.slack slack)
    (optional cfg.communication.discord discord)
    (optional cfg.communication.telegram telegram-desktop)
    (optional cfg.communication.thunderbird thunderbird)
    (optional cfg.communication.mailutils mailutils)
  ];

  writingPackages = with pkgs; flatten [
    (optional cfg.writing.libreoffice libreoffice)
    (optional cfg.writing.aspell aspell)
    (optional cfg.writing.languagetool languagetool)
    (optional cfg.writing.slides slides)
  ];

  filesPackages = with pkgs; flatten [
    (optional cfg.files.ranger ranger)
    (optional cfg.files.nnn nnn)
    (optional cfg.files.fzf fzf)
    (optional cfg.files.fd fd)
    (optional cfg.files.ripgrep ripgrep)
    (optional cfg.files.bat bat)
    (optional cfg.files.exa eza)
    (optional cfg.files.unzip unzip)
    (optional cfg.files.p7zip p7zip)
    (optional cfg.files.unrar unrar)
  ];

  automationPackages = with pkgs; flatten [
    (optional cfg.automation.expect expect)
    (optional cfg.automation.clipboard wl-clipboard)
    (optional cfg.automation.flameshot flameshot)
    (optional cfg.automation.asciinema asciinema)
  ];

  calendarPackages = with pkgs; flatten [
    (optional cfg.calendar.calcurse calcurse)
    (optional cfg.calendar.khal khal)
  ];

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
    ai_response=$(ai-cli -p openai "$ai_prompt" 2>/dev/null || echo "[]")
    
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
        ai_insights=$(ai-cli -p openai "$ai_prompt" 2>/dev/null || echo "Focus on high-priority tasks first! 🎯")
        
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

in
{
  # Enhanced productivity packages
  home.packages = flatten [
    notesPackages
    tasksPackages
    communicationPackages
    writingPackages
    filesPackages
    automationPackages
    calendarPackages

    # Required packages for AI integration
    [ pkgs.jq pkgs.bc ]
  ];

  # Enhanced shell aliases for productivity
  home.shellAliases = mkMerge [
    # Task management
    (mkIf cfg.tasks.taskwarrior {
      t = "task";
      ta = "task add";
      tl = "task list";
      td = "task done";
      tn = "task next";
      tp = "task projects";
      tt = "task tags";
    })

    (mkIf cfg.tasks.timewarrior {
      tw = "timew";
      tws = "timew start";
      twp = "timew stop";
      twt = "timew track";
      twr = "timew report";
      twd = "timew day";
    })

    # File management
    (mkIf cfg.files.ranger {
      r = "ranger";
    })


    (mkIf cfg.files.exa {
      # Note: ls alias already configured in shell/bash.nix with comprehensive options
      # Use alternative aliases to avoid conflicts
      lsl = "exa -la";
      lt = "exa --tree";
      ll = mkDefault "exa -la";
      # Use mkDefault for tree to avoid conflict with zsh.nix
      tree = mkDefault "exa --tree";
    })

    (mkIf cfg.files.fzf {
      ff = "fzf";
      fh = "history | fzf";
      # Additional fzf aliases for productivity
      fzp = "fzf --preview 'bat --color=always --line-range :50 {}'";
      fzd = "find . -type d | fzf";
    })

    # Productivity shortcuts
    (mkIf cfg.automation.flameshot {
      screenshot = "flameshot gui";
      ss = "flameshot gui";
    })

    (mkIf cfg.automation.asciinema {
      record = "asciinema rec";
      play = "asciinema play";
    })

    # AI-enhanced productivity aliases
    {
      # Smart task creation
      "smart-add" = "smart-add";
      "sa" = "smart-add"; # Quick alias

      # AI dashboard
      "ai-dashboard" = "ai-dashboard";
      "dashboard" = "ai-dashboard";
      "daily" = "ai-dashboard";
      "dash" = "ai-dashboard";
    }

    # Additional productivity aliases that complement existing shell setup
    (mkIf cfg.files.bat {
      # Alternative cat aliases that don't conflict with bash.nix
      batcat = "bat";
      preview = "bat --color=always --line-range :50";
    })

    (mkIf cfg.files.ripgrep {
      # Enhanced ripgrep aliases
      rg-code = "rg --type-add 'code:*.{js,ts,jsx,tsx,py,go,rs,nix}' --type code";
      rg-docs = "rg --type-add 'docs:*.{md,txt,org,rst}' --type docs";
    })

    (mkIf cfg.files.fd {
      # Enhanced fd aliases
      fd-code = "fd --extension js --extension ts --extension py --extension go --extension rs --extension nix";
      fd-docs = "fd --extension md --extension txt --extension org";
    })
  ];

  # Enhanced environment variables for productivity
  home.sessionVariables = mkMerge [
    # Task management configuration
    (mkIf cfg.tasks.taskwarrior {
      TASKDATA = "$HOME/.task";
      TASKRC = "$HOME/.taskrc";
    })

    # File management configuration
    (mkIf cfg.files.fzf {
      FZF_DEFAULT_COMMAND = mkDefault "fd --type f";
      FZF_CTRL_T_COMMAND = mkDefault "$FZF_DEFAULT_COMMAND";
      FZF_DEFAULT_OPTS = mkDefault "--height 40% --layout=reverse --border";
    })

    # Editor preferences
    {
      EDITOR = mkDefault "nvim";
      VISUAL = mkDefault "nvim";
      # Use mkDefault to avoid conflict with existing shell configurations
      PAGER = mkIf cfg.files.bat (mkDefault "bat");
    }
  ];

  # Note: Git configuration removed to avoid conflicts with existing git setup
  # All necessary git aliases are already configured in the shell modules


  # Note: FZF configuration is handled by the dedicated fzf module in home/shell/fzf/

  # Productivity configuration files and scripts
  home.file = mkMerge [
    # Taskwarrior configuration
    (mkIf cfg.tasks.taskwarrior {
      ".taskrc".text = ''
        # Enhanced Taskwarrior Configuration
        # Productivity-focused setup with modern features
        
        # Data location
        data.location=~/.task
        
        # Enhanced color theme
        include ${pkgs.taskwarrior3}/share/doc/task/rc/dark-256.theme
        
        # Enhanced urgency coefficients
        urgency.user.project.Inbox.coefficient=15.0
        urgency.user.project.Work.coefficient=10.0
        urgency.user.project.Personal.coefficient=5.0
        
        # Enhanced aliases
        alias.in=add +inbox
        alias.work=add +work
        alias.personal=add +personal
        alias.today=list due:today
        alias.week=list due:week
        alias.inbox=list +inbox
        
        # Enhanced reports
        report.next.description=Next tasks
        report.next.columns=id,start.age,depends,priority,project,tag,recur,scheduled.countdown,due.relative,until.remaining,description,urgency
        report.next.filter=status:pending -WAITING -inbox
        
        report.inbox.description=Inbox items to process
        report.inbox.columns=id,description
        report.inbox.filter=status:pending +inbox
        
        # Enhanced context definitions
        context.work=+work or +@work
        context.personal=+personal or +@home
        
        # Default command
        default.command=next
        
        # Enhanced UDA (User Defined Attributes)
        uda.estimate.type=string
        uda.estimate.label=Estimate
        uda.estimate.values=S,M,L,XL
        
        # Enhanced hooks (if available)
        hooks=on
      '';
    })
    # Daily productivity dashboard
    {
      ".local/bin/daily-dashboard" = {
        text = ''
          #!/bin/sh
          # Daily productivity dashboard
          echo "📅 Daily Productivity Dashboard"
          echo "==============================="
          echo
          
          # Today's date
          echo "📆 Today: $(date '+%A, %B %d, %Y')"
          echo
          
          # Task management
          ${optionalString cfg.tasks.taskwarrior ''
          echo "✅ Today's Tasks:"
          ${pkgs.taskwarrior3}/bin/task list due:today 2>/dev/null || echo "  No tasks due today"
          echo
          
          echo "📋 Inbox Items:"
          ${pkgs.taskwarrior3}/bin/task list +inbox 2>/dev/null || echo "  Inbox is empty"
          echo
          ''}
          
          # Time tracking
          ${optionalString cfg.tasks.timewarrior ''
          echo "⏰ Time Tracking:"
          ${pkgs.timewarrior}/bin/timew day 2>/dev/null || echo "  No time tracked today"
          echo
          ''}
          
          # Git status for current directory
          if [ -d .git ]; then
            echo "🔗 Git Status:"
            git status --short
            echo
          fi
          
          # System info
          echo "💻 System:"
          echo "  Uptime: $(uptime -p)"
          echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
          echo
          
          echo "🚀 Have a productive day!"
        '';
        executable = true;
      };
    }

    # Quick note creator
    (mkIf cfg.notes.obsidian {
      ".local/bin/quick-note" = {
        text = ''
          #!/bin/sh
          # Quick note creator for Obsidian
          
          NOTES_DIR="$HOME/Documents/Notes"
          DATE=$(date '+%Y-%m-%d')
          TIME=$(date '+%H:%M')
          
          # Create notes directory if it doesn't exist
          mkdir -p "$NOTES_DIR"
          
          # Note filename
          if [ $# -eq 0 ]; then
            FILENAME="$NOTES_DIR/Quick-Note-$DATE-$TIME.md"
          else
            TITLE=$(echo "$*" | tr ' ' '-')
            FILENAME="$NOTES_DIR/$TITLE-$DATE.md"
          fi
          
          # Create note with template
          cat > "$FILENAME" << EOF
          # Quick Note - $DATE $TIME
          
          ## Summary
          
          ## Details
          
          ## Tags
          #quick-note #$(date '+%Y-%m')
          
          ## Links
          
          ---
          Created: $DATE $TIME
          EOF
          
          echo "📝 Created note: $FILENAME"
          
          # Open in editor if available
          if command -v nvim >/dev/null 2>&1; then
            nvim "$FILENAME"
          else
            echo "Open with: nvim \"$FILENAME\""
          fi
        '';
        executable = true;
      };
    })

    # AI-enhanced productivity scripts
    {
      ".local/bin/smart-add" = {
        source = smartTaskAdd;
        executable = true;
      };

      ".local/bin/ai-dashboard" = {
        source = aiDashboard;
        executable = true;
      };
    }

    # Productivity helper
    {
      ".local/bin/productivity-help" = {
        text = ''
          #!/bin/sh
          # Productivity tools help
          echo "🚀 Productivity Tools"
          echo "===================="
          echo
          
          echo "📝 Available Tools:"
          ${optionalString cfg.tasks.taskwarrior ''echo "  task          - Task management (t, ta, tl, td)"''}
          ${optionalString cfg.tasks.timewarrior ''echo "  timew         - Time tracking (tw, tws, twp)"''}
          ${optionalString cfg.files.fzf ''echo "  fzf           - Fuzzy finder (ff, fh)"''}
          ${optionalString cfg.files.ranger ''echo "  ranger        - File manager (r)"''}
          ${optionalString cfg.automation.flameshot ''echo "  flameshot     - Screenshots (screenshot, ss)"''}
          ${optionalString cfg.notes.obsidian ''echo "  obsidian      - Knowledge management"''}
          echo
          
          echo "📋 Quick Commands:"
          echo "  daily-dashboard - Show productivity overview"
          ${optionalString cfg.notes.obsidian ''echo "  quick-note      - Create quick note"''}
          echo "  productivity-help - Show this help"
          echo
          
          echo "⚡ Productivity Tips:"
          echo "  - Use 'task add' to quickly capture tasks"
          echo "  - Use 'timew start <description>' to track time"
          echo "  - Use 'fzf' to quickly find files"
          echo "  - Use 'daily-dashboard' for morning planning"
        '';
        executable = true;
      };
    }
  ];
}
