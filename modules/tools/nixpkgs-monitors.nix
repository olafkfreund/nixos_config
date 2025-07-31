# NixOS Nixpkgs Update Monitoring Tools
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.tools.nixpkgs-monitors;

  # Git-based comprehensive update checker
  nixpkgs-update-checker = pkgs.writeScriptBin "nixpkgs-update-checker" ''
    #!${pkgs.bash}/bin/bash
    # NixOS Nixpkgs Update Checker - Git-based comprehensive monitoring
    
    set -euo pipefail
    
    # Dependencies available in PATH
    export PATH="${pkgs.git}/bin:${pkgs.jq}/bin:${pkgs.curl}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:$PATH"
    
    # Configuration
    NIXPKGS_DIR="''${HOME}/.local/share/nixpkgs-monitor"
    CACHE_FILE="''${HOME}/.cache/nixpkgs-updates.json"
    LOG_FILE="''${HOME}/.cache/nixpkgs-updates.log"
    
    # Colors for output
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    BOLD=$'\033[1m'
    NC=$'\033[0m' # No Color
    
    # Create directories
    mkdir -p "$(dirname "$CACHE_FILE")"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }
    
    show_help() {
        cat << EOF
    ''${BOLD}NixOS Nixpkgs Update Checker''${NC}
    
    ''${BOLD}USAGE:''${NC}
        $(basename "$0") [OPTIONS]
    
    ''${BOLD}OPTIONS:''${NC}
        -h, --help          Show this help message
        -i, --init          Initialize/clone nixpkgs repository
        -u, --update        Update and show changes
        -s, --since DAYS    Show changes since N days ago (default: 1)
        -c, --channel CH    Monitor specific channel (default: nixos-unstable)
        -f, --format FMT    Output format: simple, detailed, json (default: detailed)
        -w, --watch         Watch mode - continuously monitor for changes
        --dry-run           Show what would be updated without fetching
    
    ''${BOLD}EXAMPLES:''${NC}
        $(basename "$0") --init                    # First time setup
        $(basename "$0") --update                  # Check for updates
        $(basename "$0") --since 7                # Show changes from last 7 days
        $(basename "$0") --channel nixos-24.05    # Monitor stable channel
        $(basename "$0") --watch                   # Continuous monitoring
    
    ''${BOLD}CHANNELS:''${NC}
        nixos-unstable     Latest unstable packages (default)
        nixos-24.05        Current stable release
        nixos-23.11        Previous stable release
    EOF
    }
    
    init_nixpkgs() {
        log "Initializing nixpkgs repository..."
        
        if [[ -d "$NIXPKGS_DIR" ]]; then
            log "Repository already exists at $NIXPKGS_DIR"
            return 0
        fi
        
        mkdir -p "$NIXPKGS_DIR"
        cd "$NIXPKGS_DIR"
        
        log "Cloning nixpkgs repository..."
        git clone --depth=100 https://github.com/NixOS/nixpkgs.git .
        
        log "Setting up remote tracking..."
        git remote set-url origin https://github.com/NixOS/nixpkgs.git
        
        log "✅ Nixpkgs repository initialized at $NIXPKGS_DIR"
    }
    
    update_repo() {
        local channel="''${1:-nixos-unstable}"
        
        if [[ ! -d "$NIXPKGS_DIR" ]]; then
            log "❌ Nixpkgs repository not found. Run with --init first."
            exit 1
        fi
        
        cd "$NIXPKGS_DIR"
        
        log "Updating nixpkgs repository (channel: $channel)..."
        
        # Fetch latest changes
        git fetch origin "$channel" --depth=100
        
        # Get current and new commit hashes
        local old_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        git checkout "origin/$channel" >/dev/null 2>&1
        local new_commit=$(git rev-parse HEAD)
        
        if [[ "$old_commit" == "$new_commit" ]]; then
            log "📦 No updates available (at commit: ''${new_commit:0:8})"
            return 1
        fi
        
        log "📦 Updated from ''${old_commit:0:8} to ''${new_commit:0:8}"
        echo "$new_commit" > "''${CACHE_FILE}.commit"
        return 0
    }
    
    get_package_changes() {
        local since_days="''${1:-1}"
        local format="''${2:-detailed}"
        local channel="''${3:-nixos-unstable}"
        
        cd "$NIXPKGS_DIR"
        
        local since_date=$(date -d "$since_days days ago" '+%Y-%m-%d')
        log "Analyzing package changes since $since_date..."
        
        # Get commits affecting packages
        local commits=$(git log --since "$since_date" --oneline --grep="^[a-zA-Z][a-zA-Z0-9_-]*:" --grep="update" --grep="bump" --grep="upgrade" -i)
        
        if [[ -z "$commits" ]]; then
            log "📦 No package updates found in the last $since_days days"
            return 0
        fi
        
        case "$format" in
            "simple")
                show_simple_changes "$since_date"
                ;;
            "detailed")
                show_detailed_changes "$since_date"
                ;;
            "json")
                show_json_changes "$since_date"
                ;;
        esac
    }
    
    show_simple_changes() {
        local since_date="$1"
        
        echo "''${BOLD}📦 Package Updates Since $since_date''${NC}"
        echo "========================================"
        
        git log --since "$since_date" --oneline --pretty=format:"%h %s" | \
        grep -E "^[a-f0-9]+ [a-zA-Z][a-zA-Z0-9_-]*:" | \
        head -20 | \
        while read -r line; do
            local commit=$(echo "$line" | cut -d' ' -f1)
            local message=$(echo "$line" | cut -d' ' -f2-)
            echo "''${GREEN}•''${NC} $message ''${BLUE}($commit)''${NC}"
        done
    }
    
    show_detailed_changes() {
        local since_date="$1"
        
        echo "''${BOLD}📦 Detailed Package Updates Since $since_date''${NC}"
        echo "=================================================="
        echo
        
        # Get package updates with more details
        git log --since "$since_date" --oneline --pretty=format:"%h|%an|%ar|%s" | \
        grep -E "\|[a-zA-Z][a-zA-Z0-9_-]*:" | \
        head -20 | \
        while IFS='|' read -r commit author date message; do
            local pkg_name=$(echo "$message" | sed -E 's/^([a-zA-Z][a-zA-Z0-9_-]*):.*$/\1/')
            local action=$(echo "$message" | sed -E 's/^[a-zA-Z][a-zA-Z0-9_-]*: ?//')
            
            echo "''${YELLOW}Package:''${NC} ''${BOLD}$pkg_name''${NC}"
            echo "''${YELLOW}Action:''${NC}  $action"
            echo "''${YELLOW}Author:''${NC}  $author"
            echo "''${YELLOW}When:''${NC}    $date"
            echo "''${YELLOW}Commit:''${NC}  ''${BLUE}$commit''${NC}"
            echo
        done
    }
    
    show_json_changes() {
        local since_date="$1"
        
        echo "{"
        echo '  "last_updated": "'$(date -Iseconds)'",'
        echo '  "since_date": "'$since_date'",'
        echo '  "updates": ['
        
        local first=true
        git log --since "$since_date" --oneline --pretty=format:"%h|%an|%ar|%at|%s" | \
        grep -E "\|[a-zA-Z][a-zA-Z0-9_-]*:" | \
        head -20 | \
        while IFS='|' read -r commit author date timestamp message; do
            local pkg_name=$(echo "$message" | sed -E 's/^([a-zA-Z][a-zA-Z0-9_-]*):.*$/\1/')
            local action=$(echo "$message" | sed -E 's/^[a-zA-Z][a-zA-Z0-9_-]*: ?//' | sed 's/"/\\"/g')
            
            if [[ "$first" != "true" ]]; then
                echo ","
            fi
            first=false
            
            cat << JSON
        {
          "package": "$pkg_name",
          "action": "$action",
          "commit": "$commit",
          "author": "$author",
          "date": "$date",
          "timestamp": $timestamp
        }
    JSON
        done
        
        echo
        echo "  ]"
        echo "}"
    }
    
    watch_mode() {
        local channel="''${1:-nixos-unstable}"
        local interval=300  # 5 minutes
        
        log "🔍 Starting watch mode for channel: $channel"
        log "Checking for updates every $interval seconds..."
        echo "Press Ctrl+C to stop watching"
        echo
        
        while true; do
            if update_repo "$channel"; then
                echo "''${GREEN}🔔 New updates detected!''${NC}"
                get_package_changes 1 "detailed" "$channel"
                echo
            fi
            
            echo "''${BLUE}⏰ Next check in $interval seconds...''${NC}"
            sleep $interval
        done
    }
    
    # Parse command line arguments
    CHANNEL="nixos-unstable"
    SINCE_DAYS=1
    FORMAT="detailed"
    ACTION=""
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--init)
                ACTION="init"
                shift
                ;;
            -u|--update)
                ACTION="update"
                shift
                ;;
            -s|--since)
                SINCE_DAYS="$2"
                shift 2
                ;;
            -c|--channel)
                CHANNEL="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -w|--watch)
                ACTION="watch"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                echo "❌ Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Main execution
    case "$ACTION" in
        "init")
            init_nixpkgs
            ;;
        "update")
            if update_repo "$CHANNEL"; then
                get_package_changes "$SINCE_DAYS" "$FORMAT" "$CHANNEL"
            fi
            ;;
        "watch")
            watch_mode "$CHANNEL"
            ;;
        *)
            if [[ ! -d "$NIXPKGS_DIR" ]]; then
                echo "''${YELLOW}⚠️  Nixpkgs repository not initialized.''${NC}"
                echo "Run: $(basename "$0") --init"
                exit 1
            fi
            
            if update_repo "$CHANNEL"; then
                get_package_changes "$SINCE_DAYS" "$FORMAT" "$CHANNEL"
            fi
            ;;
    esac
  '';

  # API-based lightweight checker
  nixpkgs-api-checker = pkgs.writeScriptBin "nixpkgs-api-checker" ''
    #!${pkgs.bash}/bin/bash
    # NixOS Nixpkgs API-Based Update Checker
    
    set -euo pipefail
    
    # Dependencies available in PATH
    export PATH="${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.coreutils}/bin:$PATH"
    
    # Configuration
    CACHE_DIR="''${HOME}/.cache/nixpkgs-api"
    STATE_FILE="$CACHE_DIR/last_check.json"
    
    # Colors
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
    
    mkdir -p "$CACHE_DIR"
    
    check_api_updates() {
        local channel="''${1:-nixos-unstable}"
        local since_hours="''${2:-24}"
        
        echo "''${BOLD}🔍 Checking nixpkgs updates via GitHub API''${NC}"
        echo "Channel: $channel | Since: ''${since_hours}h ago"
        echo "================================================"
        
        # Calculate since timestamp
        local since_date=$(date -d "$since_hours hours ago" --iso-8601)
        
        # GitHub API call
        local api_url="https://api.github.com/repos/NixOS/nixpkgs/commits"
        local params="sha=$channel&since=$since_date&per_page=50"
        
        echo "📡 Fetching commits from GitHub API..."
        
        # Use curl to get commits
        local commits=$(curl -s "$api_url?$params" | jq -r '
            .[] | select(.commit.message | test("^[a-zA-Z][a-zA-Z0-9_-]*:")) |
            {
                sha: .sha[0:8],
                author: .commit.author.name,
                date: .commit.author.date,
                message: .commit.message | split("\n")[0]
            }
        ')
        
        if [[ -z "$commits" || "$commits" == "null" ]]; then
            echo "📦 No package updates found in the last ''${since_hours} hours"
            return 0
        fi
        
        echo "$commits" | jq -r '
            "📦 " + (.message | split(":")[0]) + 
            ": " + (.message | split(":")[1:] | join(":") | ltrimstr(" ")) +
            " (" + .author + ", " + (.date | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%m/%d %H:%M")) + 
            ", " + .sha + ")"
        ' | head -20
    }
    
    show_package_stats() {
        local channel="''${1:-nixos-unstable}"
        
        echo "''${BOLD}📊 Package Statistics''${NC}"
        echo "===================="
        
        # Get total packages count (approximate)
        local total_pkgs=$(${pkgs.nix}/bin/nix-env -qaP | wc -l)
        echo "Total packages: $total_pkgs"
        
        # Show most recently updated packages in your system
        echo
        echo "''${BOLD}Recently Updated in Your System:''${NC}"
        ${pkgs.nix}/bin/nix-env --list-generations | tail -5
    }
    
    show_help() {
        cat << EOF
    ''${BOLD}NixOS API-Based Update Checker''${NC}
    
    USAGE:
        $(basename "$0") [COMMAND] [CHANNEL] [HOURS]
    
    COMMANDS:
        check    Check for updates (default)
        stats    Show package statistics
        help     Show this help
    
    EXAMPLES:
        $(basename "$0")                           # Check last 24h
        $(basename "$0") check nixos-unstable 12  # Check last 12h
        $(basename "$0") stats                     # Show statistics
    EOF
    }
    
    # Main execution
    case "''${1:-check}" in
        "check")
            check_api_updates "''${2:-nixos-unstable}" "''${3:-24}"
            ;;
        "stats")
            show_package_stats "''${2:-nixos-unstable}"
            ;;
        "help")
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Run: $(basename "$0") help"
            exit 1
            ;;
    esac
  '';

  # System-focused update checker
  nixos-system-updates = pkgs.writeScriptBin "nixos-system-updates" ''
    #!${pkgs.bash}/bin/bash
    # NixOS System Update Checker
    
    set -euo pipefail
    
    # Dependencies available in PATH
    export PATH="${pkgs.nixos-rebuild}/bin:${pkgs.nix}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:$PATH"
    
    # Colors
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
    
    show_current_system() {
        echo "''${BOLD}🖥️  Current NixOS System''${NC}"
        echo "========================="
        
        local current_gen=$(nixos-rebuild list-generations | grep current | head -1)
        local nixos_version=$(nixos-version)
        local channel=$(${pkgs.nix}/bin/nix-channel --list | grep nixos || echo "No channels configured")
        
        echo "NixOS Version: $nixos_version"
        echo "Current Generation: $current_gen"
        echo "Channel: $channel"
        echo
    }
    
    check_available_updates() {
        echo "''${BOLD}🔄 Checking for Available Updates''${NC}" 
        echo "=================================="
        
        # Update channels
        echo "📡 Updating channels..."
        ${pkgs.nix}/bin/nix-channel --update nixos 2>/dev/null || true
        
        # Check what would be updated
        echo "🔍 Analyzing potential updates..."
        
        # Dry run to see what would change
        local dry_run_output=$(nixos-rebuild dry-run 2>&1 | grep -E "would (install|update|remove)" || echo "No changes detected")
        
        if [[ "$dry_run_output" == "No changes detected" ]]; then
            echo "''${GREEN}✅ System is up to date''${NC}"
            return 0
        fi
        
        echo "''${YELLOW}📦 Available Updates:''${NC}"
        echo "$dry_run_output" | while read -r line; do
            if [[ $line =~ would\ install ]]; then
                echo "''${GREEN}+ $line''${NC}"
            elif [[ $line =~ would\ update ]]; then
                echo "''${BLUE}↑ $line''${NC}"
            elif [[ $line =~ would\ remove ]]; then
                echo "''${RED}- $line''${NC}"
            fi
        done
    }
    
    show_package_versions() {
        local package="$1"
        
        echo "''${BOLD}📋 Package Version Info: $package''${NC}"
        echo "================================"
        
        # Current installed version
        local installed=$(${pkgs.nix}/bin/nix-env -q "$package" 2>/dev/null || echo "Not installed")
        echo "Installed: $installed"
        
        # Available version
        local available=$(${pkgs.nix}/bin/nix-env -qaP "$package" | head -1 | awk '{print $2}' || echo "Not found")
        echo "Available: $available"
        
        # Show derivation path
        local drv_path=$(${pkgs.nix}/bin/nix-instantiate '<nixpkgs>' -A "$package" 2>/dev/null || echo "N/A")
        echo "Derivation: $drv_path"
    }
    
    compare_generations() {
        echo "''${BOLD}📜 Recent System Generations''${NC}"
        echo "============================"
        
        nixos-rebuild list-generations | tail -10 | while read -r line; do
            if [[ $line =~ current ]]; then
                echo "''${GREEN}→ $line''${NC}"
            else
                echo "  $line"
            fi
        done
        
        echo
        echo "''${BOLD}Generation Differences:''${NC}"
        
        # Compare current with previous generation
        local current_gen=$(nixos-rebuild list-generations | grep current | awk '{print $1}')
        local prev_gen=$((current_gen - 1))
        
        if [[ $prev_gen -gt 0 ]]; then
            echo "Changes from generation $prev_gen to $current_gen:"
            ${pkgs.nix}/bin/nix-store --query --references "/nix/var/nix/profiles/system-$current_gen-link" > /tmp/current_refs
            ${pkgs.nix}/bin/nix-store --query --references "/nix/var/nix/profiles/system-$prev_gen-link" > /tmp/prev_refs 2>/dev/null || touch /tmp/prev_refs
            
            # Show added packages
            local added=$(comm -13 /tmp/prev_refs /tmp/current_refs | head -10)
            if [[ -n "$added" ]]; then
                echo "''${GREEN}Added:''${NC}"
                echo "$added" | sed 's/^/  + /'
            fi
            
            # Show removed packages
            local removed=$(comm -23 /tmp/prev_refs /tmp/current_refs | head -10)
            if [[ -n "$removed" ]]; then
                echo "''${RED}Removed:''${NC}"
                echo "$removed" | sed 's/^/  - /'
            fi
            
            rm -f /tmp/current_refs /tmp/prev_refs
        fi
    }
    
    show_flake_updates() {
        echo "''${BOLD}🔄 Flake Input Updates''${NC}"
        echo "====================="
        
        if [[ -f "flake.lock" ]]; then
            # Show current flake inputs
            echo "Current flake inputs:"
            ${pkgs.nix}/bin/nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.key != "root") | "\(.key): \(.value.locked.rev[0:8] // .value.locked.lastModified)"' | head -10
            
            echo
            echo "Checking for updates..."
            
            # Check what would be updated
            ${pkgs.nix}/bin/nix flake update --dry-run 2>/dev/null | grep -E "Updated|Warning" || echo "Run 'nix flake update' to check for updates"
        else
            echo "No flake.lock found in current directory"
        fi
    }
    
    show_help() {
        cat << EOF
    ''${BOLD}NixOS System Update Checker''${NC}
    
    USAGE:
        $(basename "$0") [COMMAND] [OPTIONS]
    
    COMMANDS:
        status      Show current system status
        check       Check for available updates  
        generations Show recent generations and changes
        package PKG Show version info for specific package
        flake       Show flake input status
        help        Show this help
    
    EXAMPLES:
        $(basename "$0")                    # Show system status
        $(basename "$0") check              # Check for updates
        $(basename "$0") package firefox    # Show Firefox version info
        $(basename "$0") generations        # Show generation history
        $(basename "$0") flake              # Show flake status
    EOF
    }
    
    # Main execution
    case "''${1:-status}" in
        "status")
            show_current_system
            ;;
        "check")
            show_current_system
            check_available_updates
            ;;
        "generations")
            compare_generations
            ;;
        "package")
            if [[ -z "''${2:-}" ]]; then
                echo "❌ Package name required"
                echo "Usage: $(basename "$0") package <package-name>"
                exit 1
            fi
            show_package_versions "$2"
            ;;
        "flake")
            show_flake_updates
            ;;
        "help")
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
  '';

  # Quick update checker combining all approaches
  nixos-updates = pkgs.writeScriptBin "nixos-updates" ''
    #!${pkgs.bash}/bin/bash
    # Quick NixOS Updates Summary - All monitoring tools in one
    
    set -euo pipefail
    
    # Colors
    BOLD=$'\033[1m'
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    NC=$'\033[0m'
    
    show_help() {
        cat << EOF
    ''${BOLD}NixOS Updates - Unified Monitoring''${NC}
    
    USAGE:
        $(basename "$0") [COMMAND]
    
    COMMANDS:
        quick       Quick summary of all updates (default)
        system      Show system status and updates
        packages    Show recent package updates
        api         Use GitHub API for latest updates
        help        Show this help
    
    EXAMPLES:
        $(basename "$0")            # Quick summary
        $(basename "$0") system     # Detailed system info
        $(basename "$0") packages   # Package updates from git
        $(basename "$0") api        # API-based check
    EOF
    }
    
    quick_summary() {
        echo "''${BOLD}🚀 NixOS Updates Quick Summary''${NC}"
        echo "==============================="
        echo
        
        # System status
        echo "''${BLUE}📊 System Status:''${NC}"
        ${nixos-system-updates}/bin/nixos-system-updates status | head -5
        echo
        
        # Recent API updates
        echo "''${BLUE}🌐 Recent Package Updates (API):''${NC}"
        ${nixpkgs-api-checker}/bin/nixpkgs-api-checker check nixos-unstable 12 | tail -n +5 | head -10
        echo
        
        # Available tools
        echo "''${YELLOW}🛠️  Available Tools:''${NC}"
        echo "  nixpkgs-update-checker  - Comprehensive git-based monitoring"
        echo "  nixpkgs-api-checker     - Fast GitHub API checking"
        echo "  nixos-system-updates    - Your system status and updates"
        echo "  nixos-updates           - This unified tool"
        echo
        echo "''${GREEN}💡 Tip: Run 'nixos-updates help' for more options''${NC}"
    }
    
    case "''${1:-quick}" in
        "quick")
            quick_summary
            ;;
        "system")
            ${nixos-system-updates}/bin/nixos-system-updates check
            ;;
        "packages")
            ${nixpkgs-update-checker}/bin/nixpkgs-update-checker --update || \
            echo "Run 'nixpkgs-update-checker --init' first for git-based monitoring"
            ;;
        "api")
            ${nixpkgs-api-checker}/bin/nixpkgs-api-checker check nixos-unstable 24
            ;;
        "help")
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
  '';

in {
  options.tools.nixpkgs-monitors = {
    enable = mkEnableOption "Enable NixOS nixpkgs monitoring tools";
    
    installAll = mkOption {
      type = types.bool;
      default = true;
      description = "Install all monitoring tools";
    };
    
    tools = mkOption {
      type = types.listOf (types.enum [ 
        "nixpkgs-update-checker" 
        "nixpkgs-api-checker" 
        "nixos-system-updates" 
        "nixos-updates" 
      ]);
      default = [ "nixpkgs-update-checker" "nixpkgs-api-checker" "nixos-system-updates" "nixos-updates" ];
      description = "List of tools to install";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = 
      (optionals (cfg.installAll || elem "nixpkgs-update-checker" cfg.tools) [ nixpkgs-update-checker ]) ++
      (optionals (cfg.installAll || elem "nixpkgs-api-checker" cfg.tools) [ nixpkgs-api-checker ]) ++
      (optionals (cfg.installAll || elem "nixos-system-updates" cfg.tools) [ nixos-system-updates ]) ++
      (optionals (cfg.installAll || elem "nixos-updates" cfg.tools) [ nixos-updates ]) ++
      [
        # Dependencies
        pkgs.git
        pkgs.jq
        pkgs.curl
      ];
    
    # Create shell aliases for convenience
    programs.bash.shellAliases = mkIf cfg.enable {
      "check-updates" = "nixos-updates quick";
      "check-packages" = "nixpkgs-api-checker";
      "check-system" = "nixos-system-updates check";
    };
    
    programs.zsh.shellAliases = mkIf cfg.enable {
      "check-updates" = "nixos-updates quick";
      "check-packages" = "nixpkgs-api-checker";
      "check-system" = "nixos-system-updates check";
    };
  };
}