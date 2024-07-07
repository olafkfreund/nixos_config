{ pkgs, ...}: {
  home.packages = with pkgs; [
    codeium
    neovide
  ];
}
