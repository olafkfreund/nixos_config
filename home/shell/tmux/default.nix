{ pkgs, ...}: {

  programs.tmux = {
    enable = true;
    clock24 = true;
    shortcut = "q";
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
      tmuxPlugins.sidebar
      tmuxPlugins.gruvbox
      tmuxPlugins.tilish
      #tmuxPlugins.sensible
    ];
    extraConfig = "
      run-shell '${pkgs.tmuxPlugins.gruvbox}/share/tmux-plugins/gruvbox/gruvbox-tpm.tmux'
      set -g @tmux-gruvbox 'dark'
      set -g default-terminal 'xterm-256color'
      # set-option -g terminal-overrides 'xterm-256color:RGB'
      set -s escape-time 0
      set -g base-index 1
      # set -g @tilish-easymode 'on'
      set -g @tilish-navigator 'on'

      #Image preview
      set -g allow-passthrough on
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM

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
    ";  
  };
}
