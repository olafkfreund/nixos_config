{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./nix.nix
    ./markdown.nix
    ./terraform.nix
    ./python.nix
    ./go.nix
    ./just.nix
    ./shell.nix
    ./yaml.nix
  ];
}
