{pkgs,
...}: {

home.packages = with pkgs; [
  git # git
    gitui # gitui
    git-credential-oauth # git credential helper for oauth
    git-credential-manager # git credential helper for github
    git-credential-1password # git credential helper for 1password
    lazygit # gitui alternative
    onefetch #Git repository summary on your terminal
];
programs.git = {
  enable = true;
  userName = "Olaf K-Freund";
  userEmail = "olaf.freund@r3.com";
};




}
