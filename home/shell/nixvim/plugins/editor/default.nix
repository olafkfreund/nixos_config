{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./telescope.nix
    ./treesitter.nix
    ./gitsigns.nix
    ./mini.nix
  ];
}
