# Enhanced Tmux Session Manager
# Smart project-based session management with fuzzy finding
{ pkgs, ... }:

pkgs.writeShellScriptBin "tmux-sessionizer" ''
  #!/usr/bin/env bash
  set -euo pipefail

  # Configuration - easily customizable search paths
  SEARCH_PATHS=(
    "$HOME/Source/GitHub"
    "$HOME/Documents"
    "$HOME/.config/nixos"
    "$HOME/Projects"
    "$HOME/workspace"
    "$HOME/dev"
  )

  # Enhanced project detection and selection
  find_projects() {
    local paths=()
    
    # Only include paths that exist
    for path in "''${SEARCH_PATHS[@]}"; do
      [[ -d "$path" ]] && paths+=("$path")
    done
    
    if [[ ''${#paths[@]} -eq 0 ]]; then
      echo "No valid search paths found" >&2
      exit 1
    fi
    
    # Find projects with enhanced filtering
    ${pkgs.fd}/bin/fd . "''${paths[@]}" \
      --min-depth 1 \
      --max-depth 3 \
      --type d \
      --hidden \
      --exclude .git \
      --exclude node_modules \
      --exclude target \
      --exclude .cache \
      --exclude .local \
      | sort -u
  }

  # Enhanced session name generation
  generate_session_name() {
    local path="$1"
    local name
    
    # Use basename and clean it up for tmux compatibility
    name=$(basename "$path" | tr '.' '_' | tr ' ' '_' | tr '-' '_')
    
    # Ensure name starts with alphanumeric character
    if [[ ! "$name" =~ ^[a-zA-Z0-9] ]]; then
      name="proj_$name"
    fi
    
    echo "$name"
  }

  # Smart project selection with preview
  select_project() {
    if [[ $# -eq 1 ]]; then
      # Direct path provided
      echo "$1"
    else
      # Interactive selection with enhanced fzf
      find_projects | ${pkgs.fzf}/bin/fzf \
        --height 40% \
        --layout=reverse \
        --border \
        --prompt=" Project: " \
        --preview "${pkgs.eza}/bin/eza --tree --level=2 --icons --group-directories-first {}" \
        --preview-window="right:50%" \
        --bind "ctrl-/:toggle-preview" \
        --bind "ctrl-u:preview-page-up" \
        --bind "ctrl-d:preview-page-down"
    fi
  }

  # Main session management logic
  main() {
    local selected
    selected=$(select_project "$@")
    
    if [[ -z "$selected" ]]; then
      exit 0
    fi
    
    if [[ ! -d "$selected" ]]; then
      echo "Error: Directory '$selected' does not exist" >&2
      exit 1
    fi
    
    local session_name
    session_name=$(generate_session_name "$selected")
    
    # Check if tmux is running
    if ! ${pkgs.tmux}/bin/tmux list-sessions &> /dev/null; then
      # No tmux server running, start new session
      exec ${pkgs.tmux}/bin/tmux new-session -s "$session_name" -c "$selected"
    fi
    
    # Tmux server exists
    if [[ -z "''${TMUX:-}" ]]; then
      # Not inside tmux, attach or create
      if ${pkgs.tmux}/bin/tmux has-session -t="$session_name" 2> /dev/null; then
        exec ${pkgs.tmux}/bin/tmux attach-session -t "$session_name"
      else
        exec ${pkgs.tmux}/bin/tmux new-session -s "$session_name" -c "$selected"
      fi
    else
      # Inside tmux, switch to session
      if ! ${pkgs.tmux}/bin/tmux has-session -t="$session_name" 2> /dev/null; then
        ${pkgs.tmux}/bin/tmux new-session -ds "$session_name" -c "$selected"
      fi
      ${pkgs.tmux}/bin/tmux switch-client -t "$session_name"
    fi
  }

  # Help function
  show_help() {
    cat << EOF
Enhanced Tmux Session Manager

Usage: tmux-sessionizer [PROJECT_PATH]

If PROJECT_PATH is provided, creates/switches to a session for that path.
Otherwise, shows an interactive fuzzy finder to select from configured paths.

Search paths:
$(printf "  %s\n" "''${SEARCH_PATHS[@]}")

Keybindings in fzf:
  Ctrl-/     Toggle preview
  Ctrl-U     Preview page up  
  Ctrl-D     Preview page down
  Enter      Select project
  Esc        Cancel

EOF
  }

  # Parse arguments
  case "''${1:-}" in
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      main "$@"
      ;;
  esac
''
