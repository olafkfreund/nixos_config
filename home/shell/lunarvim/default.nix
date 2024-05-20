<<<<<<< HEAD
{ pkgs, pkgs-stable, ...}: {
  home.packages = with pkgs-stable; [
=======
{ pkgs, ...}: {
  home.packages = with pkgs; [
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
    lunarvim
  ];
}
