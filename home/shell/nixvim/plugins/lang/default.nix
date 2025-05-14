{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    programs.nixvim.plugins = {
      treesitter = {
        enable = true;
        ensureInstalled = "all";
      };
    };
  };

  imports = [
    ./nix.nix
    ./python.nix
    ./rust.nix
    ./typescript.nix
  ];
}
