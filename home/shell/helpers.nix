{ pkgs, ... }: {

home.packages = with pkgs; [
  direnv
  ripgrep
  fzf
  aria2
  glow
  eza
  bat
  topgrade
  nerdfonts
  wtf
  starship
  thefuck
  neofetch
  lazygit
  zoxide
  less
  onefetch
  manix
  statix
  deadnix
  nixpkgs-fmt
  nixpkgs-lint
  zellij
  hollywood
  navi
  ];
}

