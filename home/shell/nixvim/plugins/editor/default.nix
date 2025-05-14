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
    ./autopairs.nix
    ./utils.nix
  ];
}
