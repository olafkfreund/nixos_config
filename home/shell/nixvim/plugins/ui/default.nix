{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./bufferline.nix
    ./lualine.nix
    ./noice.nix
    ./alpha.nix
    ./neo-tree.nix
  ];
}
