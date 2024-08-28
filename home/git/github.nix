{ pkgs, ...}: {
  home.packages = with pkgs; [
    github-copilot-cli # github copilot cli
    github-desktop # github desktop
    gh # github cli
    octofetch # github repository summary on your terminal
    lazygit
  ];
}
