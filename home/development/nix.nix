{ pkgs, ... }: {

home.packages = with pkgs; [
  nix-init
  nix-melt
  nurl
  nixpkgs-fmt
  nil
  nixos-generators
  ];
}
