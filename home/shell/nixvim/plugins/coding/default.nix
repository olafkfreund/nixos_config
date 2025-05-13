{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./lsp.nix
    ./cmp.nix
    ./copilot.nix
    ./format.nix
  ];
}
