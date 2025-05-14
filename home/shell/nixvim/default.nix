{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./config
    ./plugins
  ];

  programs.nixvim = {
    enable = true;
  };
}
