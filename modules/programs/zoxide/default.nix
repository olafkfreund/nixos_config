{ pkgs, config, lib, ... }: {
  programs.zoxide = {
    # z doc -> cd ~/Documents; zi -> interactive
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };
}