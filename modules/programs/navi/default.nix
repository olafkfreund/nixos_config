{ pkgs, lib, config, ... }: {
  programs.navi = {
    # ctrl-G
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };
}