{ pkgs, ... }: {
  home.packeges = with pkgs; [
    tldr
    tlrc
  ];
}
