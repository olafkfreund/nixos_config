{pkgs,
...}: {

  home.packages = with pkgs; [
    git
    gitui
    git-credential-oauth
    git-credential-manager
    git-credential-1password
  ];
}
