{ pkgs, ... }: {

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
    userEmail = "olaf.freund@r3.com";
  };
}
