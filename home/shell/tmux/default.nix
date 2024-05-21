{ inputs, pkgs, config, self, lib, ...}: {

programs.tmux = {
  enable = true;
  clock24 = true;
  shortcut = "a";
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
    ];
};
}
