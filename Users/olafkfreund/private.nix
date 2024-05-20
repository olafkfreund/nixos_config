
{ pkgs, lib, ... }: {

  home.packages = with pkgs; [
    git
    gitui
    git-credential-oauth
    git-credential-manager
    git-credential-1password
    lazygit
    onefetch
  ];
  programs.git = {
    enable = true;
    userName = "Olaf K-Freund";
    userEmail = lib.mkForce "olaf.loken@gmail.com";
    extraConfig.init.defaultBranch = "main";
  };
}
