{
  config,
  lib,
  pkgs,
  ...
}: with lib; let
  cfg = config.multiplexer.tmux;

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

      plugins = with pkgs; [
        tmuxPlugins.better-mouse-mode
        tmuxPlugins.urlview
        tmuxPlugins.tmux-fzf
        tmuxPlugins.tilish
        tmuxPlugins.maildir-counter
        # tmuxp
        {
          plugin = tmux-gruvbox;
          extraConfig = ''
            set -g @gruvbox_window_status_icon_enable "yes"
            set -g @gruvbox_icon_window_last "󰖰"
            set -g @gruvbox_icon_window_current "󰖯"
            set -g @gruvbox_icon_window_zoom "󰁌"
            set -g @gruvbox_icon_window_mark "󰃀"
            set -g @gruvbox_icon_window_silent "󰂛"
            set -g @gruvbox_icon_window_activity "󰖲"
            set -g @gruvbox_icon_window_bell "󰂞"

            set -g @gruvbox_flavour 'dark'
            set -g @gruvbox_window_left_separator ""
            set -g @gruvbox_window_right_separator ""
            set -g @gruvbox_window_middle_separator " █"
            set -g @gruvbox_window_number_position "right"

            set -g @gruvbox_window_default_fill "number"
            set -g @gruvbox_window_default_text "#W"

            set -g @gruvbox_window_current_fill "number"
            set -g @gruvbox_window_current_text "#W"

            set -g @gruvbox_status_modules_right "application"
            set -g @gruvbox_status_left_separator  " "
            set -g @gruvbox_status_right_separator ""

            set -g @gruvbox_status_right_separator_inverse "no"
            set -g @gruvbox_status_fill "icon"
            set -g @gruvbox_status_connect_separator "no"
            set -g @gruvbox_directory_text "#{pane_current_path}"
          '';
        }
        {
          plugin = tmuxPlugins.tilish;
          extraConfig = ''
            set -g @tilish-navigator 'on'
          '';
        }
        {
          plugin = tmuxPlugins.fzf-tmux-url;
          extraConfig = ''
            set -g @fzf-url-history-limit '2000'
            set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
            set -g @fzf-url-open "google-chrome-stable"
          '';
        }
        {
          plugin = tmuxPlugins.weather;
          extraConfig = ''
            set-option -g status-right '#{weather}'
            set-option -g @tmux-weather-location "London, UK"
            set-option -g @tmux-weather-unit 'm'
          '';
        }
        {
          plugin = tmuxPlugins.t-smart-tmux-session-manager;
          extraConfig = ''
            set -g @t-fzf-prompt '  '
            set -g @t-bind "T"
          '';
        }
        tmuxPlugins.sensible
      ];
      extraConfig = ''
        # run-shell '${pkgs.tmuxPlugins.gruvbox}/share/tmux-plugins/gruvbox/gruvbox-tpm.tmux'
        set-option -g default-terminal 'tmux-256color'
        set-option -g terminal-overrides ',xterm-256color:RGB'
        set-option -g status-position top
        run-shell /nix/store/m69nv0k6a04dzz3rya5nifdi8gr3s1a4-tmuxplugin-tmux-gruvbox-unstable-2024-06-17/share/tmux-plugins/tmux-gruvbox/gruvbox.tmux

        set -s escape-time 0
        set -g base-index 1

        #Image preview
        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM

        # Change splits to match nvim and easier to remember
        # Open new split at cwd of current split
        unbind %
        unbind '"'
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # Vim style pane selection
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Use Alt-arrow keys without prefix key to switch panes
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D

        # Shift arrow to switch windows
        bind -n S-Left  previous-window
        bind -n S-Right next-window

        # Shift Alt vim keys to switch windows
        bind -n M-H previous-window
        bind -n M-L next-window
      '';
    };
  };
}
