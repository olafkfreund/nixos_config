# Enhanced Project Management and Productivity Tools
# Note-taking, task management, time tracking, and collaboration tools
{
  pkgs,
  config,
  lib,
  host ? "default",
  ...
}:
with lib;
let
  # Productivity configuration
  cfg = {
    # Note-taking and knowledge management
    notes = {
      obsidian = true;          # Knowledge management
      logseq = false;           # Block-based notes
      zettlr = false;           # Academic writing
      notable = false;          # Markdown notes
    };
    
    # Task and project management
    tasks = {
      # CLI task management
      taskwarrior = true;       # Advanced task management
      todo_txt = false;         # Simple todo.txt format
      
      # Time tracking
      timewarrior = true;       # Time tracking companion to taskwarrior
      toggl_cli = false;        # Toggl time tracking
    };
    
    # Communication and collaboration
    communication = {
      # Chat and messaging
      slack = true;             # Team communication
      discord = true;           # Community communication
      telegram = true;          # Personal messaging
      
      # Email
      thunderbird = true;       # Email client
      mailutils = false;        # Command-line email tools
    };
    
    # Documentation and writing
    writing = {
      # Document editors
      libreoffice = false;      # Office suite
      
      # Writing tools
      aspell = true;            # Spell checker
      languagetool = false;     # Grammar checker
      
      # Presentation tools
      slides = false;           # Terminal presentations
    };
    
    # File management and organization
    files = {
      # File managers
      ranger = true;            # Terminal file manager
      nnn = false;              # Lightweight file manager
      
      # File utilities
      fzf = true;               # Fuzzy finder
      fd = true;                # Modern find replacement
      ripgrep = true;           # Modern grep replacement
      bat = true;               # Modern cat replacement
      exa = true;               # Modern ls replacement
      
      # Archive tools
      unzip = true;             # ZIP extraction
      p7zip = true;             # 7z support
      unrar = true;             # RAR support
    };
    
    # Productivity automation
    automation = {
      # Scripting and automation
      expect = false;           # Automation scripting
      
      # Clipboard management
      clipboard = true;         # Enhanced clipboard tools
      
      # Screen capture  
      flameshot = false;        # Screenshot tool (handled by desktop module)
      asciinema = true;         # Terminal recording
    };
    
    # Calendar and scheduling
    calendar = {
      calcurse = false;         # Terminal calendar
      khal = false;             # CLI calendar
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

in {
  # Enhanced productivity packages
  home.packages = flatten [
    notesPackages
    tasksPackages
    communicationPackages
    writingPackages
    filesPackages
    automationPackages
    calendarPackages
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
        include /usr/share/taskwarrior/dark-256.theme
        
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