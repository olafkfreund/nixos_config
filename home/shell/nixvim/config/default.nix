{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./keymaps.nix
    ./autocmds.nix
    ./filetypes.nix
  ];
}
