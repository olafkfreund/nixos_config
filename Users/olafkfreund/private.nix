
{ pkgs, lib, ... }: {

  home.packages = with pkgs; [
    git
    gitui
    git-credential-oauth
    git-credential-manager
    git-credential-1password
  ];
  programs.git = {
    enable = true;
    userName = "Olaf K-Freund";
    userEmail = lib.mkForce "olaf.loken@gmail.com";
  };
}
