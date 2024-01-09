{ pkgs, ... }: {

home.packages = with pkgs; [
  lua
  stylua
  sumneko-lua-language-server
  ];
}
