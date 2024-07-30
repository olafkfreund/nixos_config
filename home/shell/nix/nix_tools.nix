{ pkgs, pkgs-stable, ...}: {
  home.packages = [
    pkgs.manix #A Fast Documentation Searcher for Nix
    pkgs.statix #Lints and suggestions for the nix programming language
    pkgs.deadnix #Find and remove unused code in .nix source files
    pkgs.nixpkgs-fmt #Nix code formatter for nixpkgs
    pkgs.nixpkgs-lint
    pkgs.nix-update
    pkgs-stable.nix-doc
    pkgs.nix-bash-completions
    pkgs.nix-zsh-completions
    pkgs.nixos-container
    pkgs.nixos-generators #A utility for Nixpkgs contributors to check Nixpkgs for common errors
    pkgs.nh
    pkgs.nvd
    pkgs.nix-output-monitor
    pkgs.nixd
  ];
}
