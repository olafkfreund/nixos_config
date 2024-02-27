{ pkgs, ...}: {
  home.packages = with pkgs; [
    git # git
    gitui # gitui
    git-credential-oauth # git credential helper for oauth
    git-credential-manager # git credential helper for github
    git-credential-1password # git credential helper for 1password
    lazygit # gitui alternative
    onefetch #Git repository summary on your terminal
    github-copilot-cli # github copilot cli
    github-desktop # github desktop
    gh # github cli
    octofetch # github repository summary on your terminal
  ];
}
