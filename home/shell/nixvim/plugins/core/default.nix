{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./which-key.nix
    ./colorscheme.nix
  ];
}
