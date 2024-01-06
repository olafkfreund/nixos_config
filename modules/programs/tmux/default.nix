{ pkgs, config, lib, ... }: {

  programs.tmux = {
      enable = true;
      shortcut = "a";
      keyMode = "vi";
      baseIndex = 1;
      clock24 = true;
      newSession = true;
      secureSocket = false;
      terminal = "tmux-256color";
      plugins = with pkgs.tmuxPlugins; [
        sensible
        resurrect # prefix ctrl-s to save sessions; prefix ctrl-r to restore
        continuum # automatically save the session every 15 minutes
        sessionist # prefix g to switch sessions; prefix C to create; prefix X to kill; prefix S to switch back; prefix @ to promote; prefix t f to join marked pane
        pain-control # prefix |, -, \, _ to split; prefix h, j, k, l to switch; prefix H, J, K, L to resize; prefix <, > to move windows
        fzf-tmux-url # prefix u -> fzf urls
        yank # prefix y -> copy command line to clipboard; prefix Y -> copy pwd to clipboard; search + y -> copy to clipboard
        open # highlight: o -> open; ctrl-o -> $EDITOR; S -> web search
        vim-tmux-navigator # ctrl-h, -j, -k, -l -> move between tmux and vim splits
        extrakto # prefix tab -> fuzzy find text on screen; enter to copy; tab to paste 
      ];
      extraConfig = ''
        set -g mouse on
        set -g status-right ""
        set -g status-left ""
        set -g status-style fg=white
        set-window-option -g window-status-format '#[fg=cyan,bright,dim]#I #[fg=white,bright,dim]#W '
        set-window-option -g window-status-current-format '#[fg=cyan,bright,nodim]#I #[fg=white,bright,nodim]#W '
        set -ag terminal-overrides ",xterm-256color:RGB"
      '';
  };
}