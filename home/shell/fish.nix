{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    fishPlugins.grc
    fishPlugins.fzf
    fishPlugins.tide
    fishPlugins.sponge
    fishPlugins.plugin-git
    fishPlugins.github-copilot-cli-fish
    oh-my-fish
    grc

  ];

programs.fish = {
  enable = true; 
  };












}
