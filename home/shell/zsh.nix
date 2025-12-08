# Enhanced Modern Zsh Configuration
# Optimized for performance, maintainability, and developer experience
{ pkgs
, lib
, ...
}:
with lib; {
  imports = [
    ./claude-integration.nix
  ];

  # Optimized package selection - only essential packages
  home.packages = with pkgs; [
    # Core shell
    zsh
    oh-my-zsh
    zplug

    # Essential lightweight plugins
    zsh-edit
    zsh-autopair
    zsh-clipboard
    any-nix-shell

    # Modern shell tools
    atuin # Better history
    zoxide # Smart directory navigation
    eza # Better ls
    bat # Better cat
    ripgrep # Better grep
    fd # Better find
    bottom # Better top
    dust # Better du
    tokei # Code statistics

    # Development tools
    lazygit
    delta # Better git diff

    # Productivity
    glow # Markdown viewer
    # claude-code managed by claude-integration module
  ];

  # Enable Claude Code integration and Zsh configuration
  programs = {
    claudeCode = {
      enable = true;
      tempDir = "$HOME/.cache/claude-code";
      terminals = {
        kitty = "${pkgs.kitty}/bin/kitty";
        foot = "${pkgs.foot}/bin/foot";
        alacritty = "${pkgs.alacritty}/bin/alacritty";
        wezterm = "${pkgs.wezterm}/bin/wezterm";
      };
    };

    zsh = {
      enable = true;
      enableCompletion = true;

      # Enhanced syntax highlighting with better performance
      syntaxHighlighting = {
        enable = true;
        styles = {
          comment = "fg=#928374";
          string = "fg=#b8bb26";
          keyword = "fg=#fb4934";
          builtin = "fg=#fabd2f";
          function = "fg=#83a598";
          command = "fg=#8ec07c";
          unknown-token = "fg=#cc241d";
        };
      };

      # Enhanced autosuggestions
      autosuggestion = {
        enable = true;
        strategy = [ "history" "completion" ];
        highlight = "fg=#665c54";
      };

      # Optimized zplug configuration with lazy loading
      zplug = {
        enable = true;
        plugins = [
          {
            name = "loiccoyle/zsh-github-copilot";
            tags = [ "defer:2" ]; # Lazy load for better startup performance
          }
        ];
      };

      # Optimized plugin selection - removed redundancies and conflicts
      plugins = [
        # Essential productivity plugins
        {
          name = "zsh-fzf-tab";
          src = pkgs.zsh-fzf-tab;
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
        }

        # Nix integration (essential for NixOS)
        {
          name = "zsh-nix-shell";
          src = pkgs.zsh-nix-shell;
          file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
        }

        # Git integration
        {
          name = "zsh-forgit";
          src = pkgs.zsh-forgit;
          file = "share/zsh/zsh-forgit/forgit.plugin.zsh";
        }

        # Enhanced editing
        {
          name = "zsh-edit";
          src = pkgs.zsh-edit;
          file = "share/zsh-edit/zsh-edit.plugin.zsh";
        }

        # Nix completions
        {
          name = "nix-zsh-completions";
          src = pkgs.nix-zsh-completions;
          file = "share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh";
        }

        # Helpful suggestions (learn aliases)
        {
          name = "zsh-you-should-use";
          src = pkgs.zsh-you-should-use;
          file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
        }

        # Note: Removed zsh-syntax-highlighting plugin since we use built-in syntaxHighlighting
        # Note: Removed zsh-autosuggestions plugin since we use built-in autosuggestion
        # Note: Removed zsh-autocomplete to avoid conflicts with built-in completion
        # Note: Removed zsh-f-sy-h as it conflicts with built-in syntax highlighting
      ];

      # Fix sudo PATH issue with shell alias
      shellAliases = {
        sudo = "/run/wrappers/bin/sudo";
      };


      # Enhanced initialization with performance optimizations
      initContent = ''
        # Load completions efficiently
        fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)

        # Kitty integration (conditional and safe)
        if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
          export KITTY_SHELL_INTEGRATION="enabled"
          if [[ -r "$KITTY_INSTALLATION_DIR/shell-integration/zsh/kitty-integration" ]]; then
            autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
            kitty-integration
            unfunction kitty-integration
          fi
        fi

        # Safe sourcing of external configs
        [[ -f ~/.openai.sh ]] && source ~/.openai.sh


        # Enhanced history management
        export HISTSIZE=50000
        export SAVEHIST=50000
        export HISTFILE="$HOME/.zsh_history"
        setopt EXTENDED_HISTORY
        setopt SHARE_HISTORY
        setopt HIST_EXPIRE_DUPS_FIRST
        setopt HIST_IGNORE_DUPS
        setopt HIST_IGNORE_ALL_DUPS
        setopt HIST_FIND_NO_DUPS
        setopt HIST_IGNORE_SPACE
        setopt HIST_SAVE_NO_DUPS
        setopt HIST_VERIFY

        # MCP (Model Context Protocol) Environment Variables
        export OBSIDIAN_VAULT_PATH="$HOME/Documents/Caliti"

        # Modern history with atuin
        if command -v atuin >/dev/null 2>&1; then
          eval "$(atuin init zsh)"
        fi

        # Enhanced AIChat integration
        if command -v aichat >/dev/null 2>&1; then
          zmodload zsh/zle
          _aichat_zsh() {
            if [[ -n "$BUFFER" ]]; then
              local _old=$BUFFER
              BUFFER+="⌛"
              zle -I && zle redisplay
              local result
              result=$(aichat -e "$_old" 2>/dev/null)
              if [[ $? -eq 0 && -n "$result" ]]; then
                BUFFER="$result"
              else
                BUFFER="$_old"
              fi
              zle end-of-line
            fi
          }
          zle -N _aichat_zsh
          bindkey '\ee' _aichat_zsh
        fi
      '';

      # Enhanced completion system with performance optimizations
      completionInit = ''
        # Load essential modules
        zmodload zsh/zle
        zmodload zsh/zpty
        zmodload zsh/complist

        # Initialize colors
        autoload -Uz colors && colors

        # Smart completion cache management for better performance
        autoload -U compinit
        if [[ -n "''${ZDOTDIR}/.zcompdump"(#qN.mh+24) ]]; then
          compinit
        else
          compinit -C
        fi

        # Include hidden files in completion
        _comp_options+=(globdots)

        # Modern keybindings for enhanced navigation
        bindkey "^[[1;5C" forward-word        # Ctrl+Right
        bindkey "^[[1;5D" backward-word       # Ctrl+Left
        bindkey "^[[3;5~" forward-kill-word   # Ctrl+Delete
        bindkey "^H" backward-kill-word       # Ctrl+Backspace
        bindkey "^[[OH" beginning-of-line     # Home
        bindkey "^[[OF" end-of-line           # End

        # AI integration keybindings
        bindkey '^[|' zsh_gh_copilot_explain  # Alt+Shift+\
        bindkey '^[\\' zsh_gh_copilot_suggest  # Alt+\

        # Productivity keybindings
        bindkey -s ^f "tmux-sessionizer\n"    # Ctrl+F for session manager

        # Enhanced command editing
        autoload -z edit-command-line
        zle -N edit-command-line
        bindkey "^e" edit-command-line         # Ctrl+E for editor

        # ═══════════════════════════════════════════════════════════════════════════
        # VISUAL COMMAND BOXES - Enhanced shell experience with command visualization
        # ═══════════════════════════════════════════════════════════════════════════

        # Gruvbox Material color scheme for boxes
        typeset -gA BOX_COLORS
        BOX_COLORS=(
          [reset]='\033[0m'
          [bg]='\033[48;2;40;40;40m'          # #282828 - material dark
          [bg1]='\033[48;2;60;56;54m'         # #3c3836 - material bg1
          [fg]='\033[38;2;220;215;186m'       # #dcd7ba - material foreground
          [aqua]='\033[38;2;131;192;146m'     # #83c092 - material aqua
          [green]='\033[38;2;167;192;128m'    # #a7c080 - material green
          [yellow]='\033[38;2;219;188;127m'   # #dbbc7f - material yellow
          [red]='\033[38;2;230;126;128m'      # #e67e80 - material red
          [blue]='\033[38;2;127;187;179m'     # #7fbbb3 - material blue
          [gray]='\033[38;2;146;131;116m'     # #928374 - material gray
        )

        # Unicode box drawing characters
        typeset -gA BOX_CHARS
        BOX_CHARS=(
          [top_left]='╭'
          [top_right]='╮'
          [bottom_left]='╰'
          [bottom_right]='╯'
          [horizontal]='─'
          [vertical]='│'
          [cross]='┼'
          [tee_down]='┬'
          [tee_up]='┴'
          [bullet]='●'
          [check]='✔'
          [cross_mark]='✗'
          [arrow]='→'
        )

        # Global variables for command tracking
        typeset -g COMMAND_START_TIME
        typeset -g CURRENT_COMMAND
        typeset -g BOX_ENABLED=1

        # Function to calculate terminal width dynamically
        get_term_width() {
          local width=''${COLUMNS:-80}
          echo $width
        }

        # Function to draw horizontal line
        draw_line() {
          local length=$1
          local char=''${2:-$BOX_CHARS[horizontal]}
          printf "%*s" $length | tr ' ' "$char"
        }

        # Function to draw a command box header
        draw_command_box() {
          local command="$1"
          local term_width=$(get_term_width)
          local max_content_width=$((term_width - 4))  # Account for │ │ padding

          # Truncate command if too long
          if [[ ''${#command} -gt $max_content_width ]]; then
            command="''${command:0:$((max_content_width - 3))}..."
          fi

          local content_width=''${#command}
          local padding_needed=$((max_content_width - content_width))
          local left_padding=$((padding_needed / 2))
          local right_padding=$((padding_needed - left_padding))

          # Top border
          printf "''${BOX_COLORS[aqua]}%s" "''${BOX_CHARS[top_left]}"
          draw_line $((max_content_width + 2))
          printf "%s''${BOX_COLORS[reset]}\n" "''${BOX_CHARS[top_right]}"

          # Command line with proper centering
          printf "''${BOX_COLORS[aqua]}%s ''${BOX_COLORS[fg]}" "''${BOX_CHARS[vertical]}"
          printf "%*s%s%*s" $left_padding "" "$command" $right_padding ""
          printf " ''${BOX_COLORS[aqua]}%s''${BOX_COLORS[reset]}\n" "''${BOX_CHARS[vertical]}"

          # Bottom border
          printf "''${BOX_COLORS[aqua]}%s" "''${BOX_CHARS[bottom_left]}"
          draw_line $((max_content_width + 2))
          printf "%s''${BOX_COLORS[reset]}\n" "''${BOX_CHARS[bottom_right]}"
        }

        # Function to draw command result box
        draw_result_box() {
          local exit_code=$1
          local duration=$2
          local term_width=$(get_term_width)
          local max_content_width=$((term_width - 4))

          # Determine result status and color
          local status_icon result_text color
          if [[ $exit_code -eq 0 ]]; then
            status_icon="''${BOX_CHARS[check]}"
            result_text="Command completed successfully"
            color="''${BOX_COLORS[green]}"
          else
            status_icon="''${BOX_CHARS[cross_mark]}"
            result_text="Command failed (exit code: $exit_code)"
            color="''${BOX_COLORS[red]}"
          fi

          # Add duration if available
          if [[ -n "$duration" ]]; then
            result_text="$result_text in ''${duration}s"
          fi

          # Truncate if too long
          if [[ ''${#result_text} -gt $max_content_width ]]; then
            result_text="''${result_text:0:$((max_content_width - 3))}..."
          fi

          local content="$status_icon  $result_text"
          local content_width=''${#content}
          local padding_needed=$((max_content_width - content_width))
          local right_padding=$padding_needed

          # Top border
          printf "''${color}%s" "''${BOX_CHARS[top_left]}"
          draw_line $((max_content_width + 2))
          printf "%s''${BOX_COLORS[reset]}\n" "''${BOX_CHARS[top_right]}"

          # Result line
          printf "''${color}%s ''${BOX_COLORS[fg]}" "''${BOX_CHARS[vertical]}"
          printf "%s%*s" "$content" $right_padding ""
          printf " ''${color}%s''${BOX_COLORS[reset]}\n" "''${BOX_CHARS[vertical]}"

          # Bottom border
          printf "''${color}%s" "''${BOX_CHARS[bottom_left]}"
          draw_line $((max_content_width + 2))
          printf "%s''${BOX_COLORS[reset]}\n" "''${BOX_CHARS[bottom_right]}"
        }

        # Preexec hook - called before command execution
        preexec_command_box() {
          [[ $BOX_ENABLED -eq 0 ]] && return

          # Store command and start time
          CURRENT_COMMAND="$1"
          COMMAND_START_TIME=$EPOCHSECONDS

          # Draw command box
          echo
          draw_command_box "> $1"
        }

        # Precmd hook - called before each prompt
        precmd_command_box() {
          [[ $BOX_ENABLED -eq 0 ]] && return

          # Only show result if we have a command
          if [[ -n "$CURRENT_COMMAND" ]]; then
            local exit_code=$?
            local duration=""

            # Calculate duration if start time is available
            if [[ -n "$COMMAND_START_TIME" ]]; then
              duration=$((EPOCHSECONDS - COMMAND_START_TIME))
            fi

            # Draw result box
            draw_result_box $exit_code "$duration"
            echo

            # Reset for next command
            CURRENT_COMMAND=""
            COMMAND_START_TIME=""
          fi
        }

        # Function to toggle boxes on/off
        toggle_boxes() {
          if [[ $BOX_ENABLED -eq 1 ]]; then
            BOX_ENABLED=0
            echo "''${BOX_COLORS[yellow]}Command boxes disabled''${BOX_COLORS[reset]}"
          else
            BOX_ENABLED=1
            echo "''${BOX_COLORS[green]}Command boxes enabled''${BOX_COLORS[reset]}"
          fi
        }

        # Register hooks
        autoload -Uz add-zsh-hook
        add-zsh-hook preexec preexec_command_box
        add-zsh-hook precmd precmd_command_box

        # Add alias to toggle boxes
        alias boxes='toggle_boxes'

        # ═══════════════════════════════════════════════════════════════════════════════════════════
        # STARSHIP VISUAL SEPARATOR - Add visual line before each prompt
        # ═══════════════════════════════════════════════════════════════════════════════════════════

        # Global variable to control separator
        typeset -g SEPARATOR_ENABLED=1

        # Function to draw a visual separator line
        draw_prompt_separator() {
          [[ $SEPARATOR_ENABLED -eq 0 ]] && return

          local width=''${COLUMNS:-80}
          local line_color='\033[38;2;146;131;116m'  # Gruvbox material gray
          local reset_color='\033[0m'

          # Draw a subtle separator line
          printf "''${line_color}"
          printf '%.0s─' $(seq 1 $((width)))
          printf "''${reset_color}\\n"
        }

        # Precmd hook for visual separator (runs before each prompt, after command boxes)
        precmd_visual_separator() {
          # Only run if separator is enabled and we're interactive
          if [[ $SEPARATOR_ENABLED -eq 1 && -o interactive ]]; then
            draw_prompt_separator
          fi
        }

        # Function to toggle separator on/off
        toggle_separator() {
          if [[ $SEPARATOR_ENABLED -eq 1 ]]; then
            SEPARATOR_ENABLED=0
            echo "''${BOX_COLORS[yellow]}Visual separator disabled''${BOX_COLORS[reset]}"
          else
            SEPARATOR_ENABLED=1
            echo "''${BOX_COLORS[green]}Visual separator enabled''${BOX_COLORS[reset]}"
          fi
        }

        # Register the separator hook (after command boxes to avoid conflicts)
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd precmd_visual_separator

        # Add alias to toggle separator
        alias separator='toggle_separator'

        # Enhanced completion styling with better performance
        zstyle ':completion:*' menu no
        zstyle ':completion:*' complete true
        zstyle ':completion:*' complete-options true
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
        zstyle ':completion:*' keep-prefix true
        zstyle ':completion:*' list-grouped false
        zstyle ':completion:*' list-separator ""
        zstyle ':completion:*' group-name ""
        zstyle ':completion:*' verbose yes
        zstyle ':completion:*:matches' group 'yes'
        zstyle ':completion:*:warnings' format '%F{red}%B-- No match for: %d --%b%f'
        zstyle ':completion:*:messages' format '%d'
        zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
        zstyle ':completion:*:descriptions' format '[%d]'

        # Directory completion
        zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
        zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
        zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
        zstyle ':completion:*:*:-command-:*:*' group-order aliases builtins functions commands
        zstyle ':completion:*' special-dirs true
        zstyle ':completion:*' squeeze-slashes true

        # Optimized sorting for better performance
        zstyle ':completion:*' sort false
        zstyle ":completion:*:git-checkout:*" sort false
        zstyle ':completion:*' file-sort modification
        zstyle ':completion:*:eza' sort false
        zstyle ':completion:complete:*:options' sort false
        zstyle ':completion:files' sort false

        # Enhanced fzf-tab configuration
        zstyle ':fzf-tab:*' use-fzf-default-opts yes
        zstyle ':fzf-tab:complete:*:*' fzf-preview 'eza --icons -a --group-directories-first -1 --color=always $realpath'
        zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w -w'
        zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
        zstyle ':fzf-tab:*' fzf-command fzf
        zstyle ':fzf-tab:*' fzf-pad 4
        zstyle ':fzf-tab:*' fzf-min-height 100
        zstyle ':fzf-tab:*' switch-group ',' '.'
      '';

      # Environment variables for enhanced shell experience
      envExtra = ''
        # Set TERM appropriately based on terminal and multiplexer
        if [[ "$TMUX" != "" ]]; then
          export TERM=tmux-256color
        else
          export TERM=xterm-256color
        fi
        export BROWSER="firefox"
        export EDITOR="nvim"
        export VISUAL="$EDITOR"

        # Performance optimizations
        export KEYTIMEOUT=1
        export REPORTTIME=10
        export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
        export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

        # Better defaults for common tools
        export LESS="-F -g -i -M -R -S -w -X -z-4"
        export PAGER="less"
        export MANPAGER="sh -c 'col -bx | bat -l man -p'"
        export MANROFFOPT="-c"

        # Enhanced history settings
        export HISTCONTROL="ignoreboth:erasedups"
        export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help:man *:history"

        # Modern tool configurations
        export BAT_THEME="gruvbox-dark"
        export EZA_COLORS="da=1;34:gm=1;34"
      '';

      # Optimized Oh My Zsh configuration with essential plugins only
      oh-my-zsh = {
        enable = true;
        plugins = [
          "sudo" # Essential utility
          "direnv" # Development environment
          "history" # History management
          "starship" # Prompt integration
          "git" # Git integration
          "terraform" # Infrastructure
          "aws" # Cloud
          "azure" # Cloud
          "1password" # Productivity
          "emoji-clock" # Fun utility
          "lxd" # Containers
        ];
        theme = "gruvbox";
      };

      # Enhanced shell aliases - only forcing critical improvements where needed
      shellAliases = {
        # Core Git enhancements (using mkForce to override existing)
        gc = lib.mkForce "git commit -v"; # More verbose commits
        gl = lib.mkForce "git log --oneline --graph --decorate"; # Better git log

        # Modern ls replacement with eza (force override existing ls aliases)
        ls = lib.mkForce "eza --icons=auto --color=auto --group-directories-first";
        ll = lib.mkForce "eza --icons=auto --color=auto --long --group-directories-first --git";
        la = lib.mkForce "eza --icons=auto --color=auto --long --all --group-directories-first --git";
        l = lib.mkForce "eza --icons=auto --color=auto --long --group-directories-first";

        # Additional eza aliases for enhanced file operations
        lt = lib.mkForce "eza --icons=auto --color=auto --tree --level=2 --group-directories-first";
        lta = "eza --icons=auto --color=auto --tree --level=2 --all --group-directories-first";
        lr = "eza --icons=auto --color=auto --long --reverse --sort=modified --group-directories-first";
        lz = "eza --icons=auto --color=auto --long --sort=size --group-directories-first";

        # NixOS management aliases
        nhs = "nh os switch";
        nhu = "nh home switch";

        # Safe unique aliases
        reload = "exec zsh";
        weather = "curl -s https://wttr.in/London";
        myip = "curl -s https://ipinfo.io/ip";
        ezals = "eza --header --git --classify --long --binary --group --time-style=long-iso --links --all --group-directories-first --sort=name --icons";
        fzfpreview = "fzf --preview 'bat --color=always --line-range :50 {}'";
        aiexplain = "aichat --role explain";
      };
    };

    # Additional programs for enhanced shell experience

    # Modern directory navigation
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # Enhanced directory listing
    eza = {
      enable = true;
      enableZshIntegration = false; # We define our own aliases
      icons = "auto";
      git = true;
    };

    # Note: bat configuration managed by home/shell/bat/default.nix

    # Modern git UI
    lazygit = {
      enable = true;
    };
  };
}
