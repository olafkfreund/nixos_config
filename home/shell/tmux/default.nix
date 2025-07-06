# Enhanced Modern Tmux Configuration
# Optimized for speed, maintainability, and seamless integration with Zsh/Starship
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.multiplexer.tmux;

  # Modern Gruvbox theme with enhanced icons and performance
  tmux-gruvbox =
    pkgs.tmuxPlugins.mkTmuxPlugin
    {
      pluginName = "tmux-gruvbox";
      version = "unstable-2024-06-17";
      src = pkgs.fetchFromGitHub {
        owner = "z3z1ma";
        repo = "tmux-gruvbox";
        rev = "master";
        sha256 = "sha256-wBhOKM85aOcV4jD7wdyB/zXKDdhODE5k1iud+cm6Wk0=";
      };
    };
in {
  options.multiplexer.tmux = {
    enable = mkEnableOption {
      default = true;
      description = "tmux";
    };
  };
  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      clock24 = true;
      shortcut = "b";
      aggressiveResize = true;
      baseIndex = 1;
      newSession = true;
      escapeTime = 0;
      secureSocket = true;
      mouse = true;

      # Curated plugin selection for optimal performance and functionality
      plugins = with pkgs; [
        # Core functionality
        tmuxPlugins.sensible              # Better defaults
        tmuxPlugins.better-mouse-mode     # Enhanced mouse support
        
        # Navigation and window management
        {
          plugin = tmuxPlugins.tilish;
          extraConfig = ''
            # Tiling window management like i3/sway
            set -g @tilish-navigator 'on'
            set -g @tilish-default 'main-vertical'
          '';
        }
        
        # Enhanced session management
        {
          plugin = tmuxPlugins.t-smart-tmux-session-manager;
          extraConfig = ''
            # Smart session switching with fzf integration
            set -g @t-fzf-prompt '   Session: '
            set -g @t-bind "T"
            set -g @t-fzf-default-results 'sessions'
          '';
        }
        
        # Modern fuzzy finding
        {
          plugin = tmuxPlugins.tmux-fzf;
          extraConfig = ''
            # Enhanced fzf integration for tmux operations
            set -g @tmux-fzf-launch-key 'C-f'
            set -g @tmux-fzf-order 'session|window|pane|command|keybinding'
          '';
        }
        
        # URL handling with modern browser integration
        {
          plugin = tmuxPlugins.fzf-tmux-url;
          extraConfig = ''
            set -g @fzf-url-history-limit '3000'
            set -g @fzf-url-fzf-options '-p 70%,40% --prompt="   " --border-label=" 🌐 Open URL " --preview-window="right:50%"'
            set -g @fzf-url-open "${pkgs.firefox}/bin/firefox"
            set -g @fzf-url-bind 'u'
          '';
        }
        
        # Enhanced Gruvbox theme with modern icons
        {
          plugin = tmux-gruvbox;
          extraConfig = ''
            # Modern icon set for better visual feedback
            set -g @gruvbox_window_status_icon_enable "yes"
            set -g @gruvbox_icon_window_last "󰖰"
            set -g @gruvbox_icon_window_current "󰖯"
            set -g @gruvbox_icon_window_zoom "󰁌"
            set -g @gruvbox_icon_window_mark "󰃀"
            set -g @gruvbox_icon_window_silent "󰂛"
            set -g @gruvbox_icon_window_activity "󰖲"
            set -g @gruvbox_icon_window_bell "󰂞"
            
            # Theme configuration for consistency with Starship
            set -g @gruvbox_flavour 'dark'
            set -g @gruvbox_window_left_separator ""
            set -g @gruvbox_window_right_separator ""
            set -g @gruvbox_window_middle_separator " █"
            set -g @gruvbox_window_number_position "right"
            
            # Window display settings
            set -g @gruvbox_window_default_fill "number"
            set -g @gruvbox_window_default_text "#W#{?window_zoomed_flag, 󰁌,}"
            set -g @gruvbox_window_current_fill "number"
            set -g @gruvbox_window_current_text "#W#{?window_zoomed_flag, 󰁌,}"
            
            # Status line modules for development workflow
            set -g @gruvbox_status_modules_right "directory session date_time"
            set -g @gruvbox_status_left_separator " "
            set -g @gruvbox_status_right_separator ""
            set -g @gruvbox_status_right_separator_inverse "no"
            set -g @gruvbox_status_fill "icon"
            set -g @gruvbox_status_connect_separator "no"
            
            # Smart directory display
            set -g @gruvbox_directory_text "#{s|$HOME|~|:pane_current_path}"
          '';
        }
        
        # Development productivity plugins
        tmuxPlugins.tmux-thumbs           # Quick text copying
        tmuxPlugins.extrakto              # Enhanced text extraction
      ];
      
      # Enhanced configuration for modern terminal workflows
      extraConfig = ''
        # ========== Terminal and Display Settings ==========
        set-option -g default-terminal 'tmux-256color'
        set-option -g terminal-overrides ',xterm-256color:RGB,alacritty:RGB,kitty:RGB,foot:RGB,wezterm:RGB'
        set-option -g status-position top
        set-option -ga terminal-overrides ',*:Tc' # True color support
        
        # Performance optimizations
        set -s escape-time 0              # Remove delay for ESC key
        set -g repeat-time 600            # Increase repeat timeout
        set -g focus-events on            # Enable focus events
        set -g aggressive-resize on       # Aggressive resizing
        
        # Modern terminal features
        set -g allow-passthrough on       # Image preview support
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM
        set -ga update-environment SSH_TTY
        set -ga update-environment DISPLAY
        set -ga update-environment WAYLAND_DISPLAY
        
        # ========== Base Configuration ==========
        set -g base-index 1               # Start windows at 1
        set -g pane-base-index 1          # Start panes at 1
        set -g renumber-windows on        # Renumber windows when closed
        set -g set-titles on              # Set terminal title
        set -g set-titles-string '#h ⸰ #S ● #I #W'
        
        # History and scrollback
        set -g history-limit 50000        # Increase history limit
        set -g display-time 4000          # Display messages for 4 seconds
        set -g status-interval 5          # Update status every 5 seconds
        
        # ========== Enhanced Keybindings ==========
        # Reload configuration
        bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
        
        # Smart pane splitting (intuitive and current directory aware)
        unbind %
        unbind '"'
        bind | split-window -h -c "#{pane_current_path}" # Vertical split
        bind - split-window -v -c "#{pane_current_path}" # Horizontal split
        bind '\' split-window -h -c "#{pane_current_path}" # Alternative vertical
        bind _ split-window -v -c "#{pane_current_path}"  # Alternative horizontal
        
        # Smart window creation
        bind c new-window -c "#{pane_current_path}"      # New window at current path
        bind C new-window                                 # New window at home
        
        # ========== Vim-Style Navigation ==========
        # Pane navigation (vim-style with fallback)
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R
        
        # Pane resizing (vim-style)
        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5
        
        # Alt-arrow keys for pane switching (no prefix)
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D
        
        # Alt-vim keys for pane switching (no prefix)
        bind -n M-h select-pane -L
        bind -n M-l select-pane -R
        bind -n M-k select-pane -U
        bind -n M-j select-pane -D
        
        # ========== Window Management ==========
        # Window switching
        bind -n S-Left previous-window
        bind -n S-Right next-window
        bind -n M-H previous-window
        bind -n M-L next-window
        
        # Quick window access
        bind -n M-1 select-window -t 1
        bind -n M-2 select-window -t 2
        bind -n M-3 select-window -t 3
        bind -n M-4 select-window -t 4
        bind -n M-5 select-window -t 5
        
        # ========== Copy Mode Enhancements ==========
        # Vim-style copy mode
        set-window-option -g mode-keys vi
        bind Enter copy-mode
        bind -T copy-mode-vi 'v' send -X begin-selection
        bind -T copy-mode-vi 'y' send -X copy-selection-and-cancel
        bind -T copy-mode-vi 'r' send -X rectangle-toggle
        bind -T copy-mode-vi Escape send -X cancel
        
        # Mouse support with modern clipboard integration
        bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
        bind -n MouseDown2Pane run "${pkgs.wl-clipboard}/bin/wl-paste | tmux load-buffer - && tmux paste-buffer"
        
        # ========== Session Management ==========
        # Enhanced session switching
        bind s choose-tree -sZ -O name
        bind S new-session
        
        # Quick session access
        bind -n M-s choose-tree -sZ -O name
        
        # ========== Development Workflow ==========
        # Quick pane layouts for development
        bind M-1 select-layout even-horizontal
        bind M-2 select-layout even-vertical
        bind M-3 select-layout main-horizontal
        bind M-4 select-layout main-vertical
        bind M-5 select-layout tiled
        
        # Zoom pane toggle
        bind z resize-pane -Z
        
        # Clear screen and history
        bind C-l send-keys 'clear' Enter \; clear-history
        
        # ========== Apply Theme ==========
        run-shell "${tmux-gruvbox}/share/tmux-plugins/tmux-gruvbox/gruvbox.tmux"
      '';
    };
  };
}