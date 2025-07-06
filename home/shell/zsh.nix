# Enhanced Modern Zsh Configuration
# Optimized for performance, maintainability, and developer experience
{pkgs, lib, config, ...}:
with lib;
{
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
    atuin          # Better history
    zoxide         # Smart directory navigation
    eza            # Better ls
    bat            # Better cat
    ripgrep        # Better grep
    fd             # Better find
    bottom         # Better top
    dust           # Better du
    tokei          # Code statistics
    
    # Development tools
    lazygit
    delta          # Better git diff
    
    # Productivity
    glow           # Markdown viewer
    # claude-code managed by claude-integration module
  ];

  # Enable Claude Code integration
  programs.claudeCode = {
    enable = true;
    tempDir = "$HOME/.cache/claude-code";
    terminals = {
      kitty = "${pkgs.kitty}/bin/kitty";
      foot = "${pkgs.foot}/bin/foot";
      alacritty = "${pkgs.alacritty}/bin/alacritty";
      wezterm = "${pkgs.wezterm}/bin/wezterm";
    };
  };

  programs.zsh = {
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
      export TERM=xterm-256color
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
        "sudo"         # Essential utility
        "direnv"       # Development environment
        "history"      # History management
        "starship"     # Prompt integration
        "git"          # Git integration
        "terraform"    # Infrastructure
        "aws"          # Cloud
        "azure"        # Cloud
        "1password"    # Productivity
        "emoji-clock"  # Fun utility
        "lxd"          # Containers
      ];
      theme = "gruvbox";
    };

    # Enhanced shell aliases - only forcing critical improvements where needed
    shellAliases = {
      # Core Git enhancements (using mkForce to override existing)
      gc = lib.mkForce "git commit -v";  # More verbose commits
      gl = lib.mkForce "git log --oneline --graph --decorate";  # Better git log
      
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
  programs = {
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