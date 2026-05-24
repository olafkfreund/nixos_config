# Enhanced Modern Tmux Configuration
# Optimized for speed, maintainability, and seamless integration with Zsh/Starship
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.multiplexer.tmux;
  inherit (config.lib.stylix) colors;

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
in
{
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
      terminal = "tmux-256color";
      keyMode = "vi";
      focusEvents = true;

      # Curated plugin selection for optimal performance and functionality
      plugins = with pkgs; [
        # Core functionality
        tmuxPlugins.sensible # Better defaults
        tmuxPlugins.better-mouse-mode # Enhanced mouse support

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
            set -g @gruvbox_window_left_separator "│"
            set -g @gruvbox_window_right_separator "│"
            set -g @gruvbox_window_middle_separator "│"
            set -g @gruvbox_window_number_position "right"

            # Window display settings
            set -g @gruvbox_window_default_fill "number"
            set -g @gruvbox_window_default_text "#W#{?window_zoomed_flag, 󰁌,}"
            set -g @gruvbox_window_current_fill "number"
            set -g @gruvbox_window_current_text "#W#{?window_zoomed_flag, 󰁌,}"

            # Status line modules for development workflow
            set -g @gruvbox_status_modules_right "directory session date_time"
            set -g @gruvbox_status_left_separator "│"
            set -g @gruvbox_status_right_separator "│"
            set -g @gruvbox_status_right_separator_inverse "no"
            set -g @gruvbox_status_fill "icon"
            set -g @gruvbox_status_connect_separator "no"

            # Smart directory display
            set -g @gruvbox_directory_text "#{s|$HOME|~|:pane_current_path}"
          '';
        }

        # Development productivity plugins
        tmuxPlugins.tmux-thumbs # Quick text copying
        tmuxPlugins.extrakto # Enhanced text extraction
      ];

      # Enhanced configuration for modern terminal workflows
      extraConfig = ''
        # ========== tmux-expose ==========
        # Mission Control-style session switcher with live previews.
        # Binary lives at ${pkgs.customPkgs.tmux-expose}/bin/tmux-expose.
        # Default trigger M-e (matches upstream tmux.expose.tmux defaults).
        # Inlined here rather than via mkTmuxPlugin because the upstream
        # .tmux file is a thin 5-line keybinder we can replicate directly.
        bind-key -T root M-e display-popup -w "100%" -h "100%" -E "${pkgs.customPkgs.tmux-expose}/bin/tmux-expose"

        # ========== tmux-palette ==========
        # Raycast-style command palette. M-p opens the default `commands`
        # palette (built-in tmux actions + windows + sessions). M-a opens
        # our custom `ai-tools` palette (Claude Code, Claude Agents,
        # Gemini CLI — see xdg.configFile."tmux-palette/palettes/ai-tools.json"
        # below).
        #
        # Note on M-Space: GNOME (Mutter) reserves Alt+Space by default
        # for the Window Menu shortcut. Disable it in
        # Settings → Keyboard → View and Customise Shortcuts → Windows
        # → "Activate window menu" (or via dconf). Both M-Space and M-p
        # are bound here so either works regardless of DE config.
        bind-key -n M-Space run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette'
        bind-key -n M-p     run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette'
        bind-key -n M-a     run-shell '${pkgs.customPkgs.tmux-palette}/bin/tmux-palette ai-tools'

        # ========== Terminal and Display Settings ==========
        set-option -g terminal-overrides ',xterm-256color:RGB,alacritty:RGB,kitty:RGB,foot:RGB,wezterm:RGB,ghostty:RGB'
        set-option -g status-position top
        set-option -ga terminal-overrides ',*:Tc' # True color support

        # Fix powerline alignment and character rendering
        set-option -ga terminal-overrides ',*:sitm=\E[3m'  # Fix italic support
        set-option -ga terminal-overrides ',*:smcup@:rmcup@' # Fix screen buffer
        set-option -g status-justify left # Ensure left alignment

        # Performance optimizations
        set -g repeat-time 600            # Increase repeat timeout
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

        # Status line alignment fixes
        set -g status-left-length 40      # Ensure adequate left space
        set -g status-right-length 120    # Ensure adequate right space
        set -g window-status-separator ""  # Remove extra separators

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
        # Smart pane switching with awareness of Vim splits.
        # Integrates with nvim-tmux-navigation Lua plugin.
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
        bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
        bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
        bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
        bind-key -n 'C-\' if-shell "$is_vim" 'send-keys C-\\' 'select-pane -l'

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
        bind Enter copy-mode
        bind -T copy-mode-vi 'v' send -X begin-selection
        bind -T copy-mode-vi 'y' send -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
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

        # ========== Override Theme Settings for Alignment ==========
        # Apply our alignment fixes after theme loads
        set -g status-left-length 40      # Override theme left length
        set -g status-right-length 120    # Override theme right length
        set -g window-status-separator " " # Clean separator between windows

        # ========== Remove Round Corners and Fix Powerline ==========
        # Force flat separators and prevent powerline curve characters
        set -g status-left "#{?client_prefix,#[bg=#${colors.base0A}]#[fg=#${colors.base00}],#[bg=#${colors.base0D}]#[fg=#${colors.base00}]} #S #[fg=default,bg=default] "
        set -g status-right " #[fg=#${colors.base04}]#{s|$HOME|~|:pane_current_path} │ %H:%M │ %d-%b "

        # Override window status format to ensure clean appearance
        set -g window-status-format " #I #W "
        set -g window-status-current-format " #I #W "

        # Ensure no powerline characters are used
        set -g window-status-separator " │ "
        set -g status-style "bg=#${colors.base00},fg=#${colors.base04}"

        # Popup chrome — match the Stylix base16 scheme so display-popup
        # (tmux-palette, tmux-expose, choose-tree -Z, etc.) blends into the
        # terminal instead of using tmux's terminal-default fill which
        # renders darker than gruvbox bg on kitty/ghostty.
        set -g popup-style "bg=#${colors.base00}"
        set -g popup-border-style "fg=#${colors.base0B},bg=#${colors.base00}"
        set -g popup-border-lines rounded
      '';
    };

    # tmux-palette active theme — full color override sourced from our
    # active stylix base16 scheme, so the palette popup is BYTE-IDENTICAL
    # to the rest of our terminal/UI gruvbox theming (not just close-ish
    # to the tmux-palette-bundled gruvbox-dark, which uses slightly
    # different panel/selected/muted/accent values).
    #
    # Schema discovered from src/theme.ts:
    #   { name: "<slug>" }              → look up bundled/user slug
    #   { bg, panel, selected, fg, muted, accent }  → full Theme override
    #   partial Theme                   → merged onto default theme
    # Note: the field is `name`, NOT `theme` — earlier `theme.json` of
    # `{ "theme": "gruvbox-dark" }` was silently ignored (treated as a
    # Partial<Theme>) and crashed the palette with exit 1.
    #
    # base16 → tmux-palette Theme mapping:
    #   bg       = base00 (default background)
    #   panel    = base01 (lighter background)
    #   selected = base02 (selection / line-highlight)
    #   fg       = base05 (default foreground)
    #   muted    = base03 (comments / dim)
    #   accent   = base0B (green — gruvbox's classic positive accent)
    xdg.configFile."tmux-palette/theme.json".text = builtins.toJSON {
      bg = "#${colors.base00}";
      panel = "#${colors.base01}";
      selected = "#${colors.base02}";
      fg = "#${colors.base05}";
      muted = "#${colors.base03}";
      accent = "#${colors.base0B}";
    };

    # tmux-palette AI launcher: triggered by the M-a bind defined above.
    # The palette runs `command` and parses its JSON output as a list of
    # items, each with its own action. We emit a static JSON array via
    # `echo` of a Nix-generated string — keeps the keystrokes/args
    # bullet-proof (Nix handles all shell escaping) and makes it trivial
    # to add more AI tools later without touching the .nix file.
    xdg.configFile."tmux-palette/palettes/ai-tools.json".text = builtins.toJSON {
      title = "AI Tools";
      icon = "🤖";
      command = "echo " + lib.escapeShellArg (builtins.toJSON [
        {
          icon = "⚡";
          iconColor = "#cc8822";
          title = "Claude Code (Popup)";
          subtitle = "Launch Claude overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'claude --dangerously-skip-permissions --resume --remote-control'";
        }
        {
          icon = "⚡";
          iconColor = "#cc8822";
          title = "Claude Code (Split Right)";
          subtitle = "Open Claude in a 35% side split";
          action.tmux = "split-window -h -l 35% -c '#{pane_current_path}' 'claude --dangerously-skip-permissions --resume --remote-control'";
        }
        {
          icon = "🛰";
          iconColor = "#a48ec3";
          title = "Claude Agents (Popup)";
          subtitle = "Launch agents overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'claude agents --dangerously-skip-permissions'";
        }
        {
          icon = "🛸";
          iconColor = "#22aaff";
          title = "Antigravity CLI (Popup)";
          subtitle = "Launch agy overlay in floating window";
          action.tmux = "display-popup -w 85% -h 85% -d '#{pane_current_path}' -E 'agy'";
        }
        {
          icon = "🛸";
          iconColor = "#22aaff";
          title = "Antigravity CLI (Split Right)";
          subtitle = "Open agy in a 35% side split";
          action.tmux = "split-window -h -l 35% -c '#{pane_current_path}' 'agy'";
        }
      ]);
    };
  };
}
