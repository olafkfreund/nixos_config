{ pkgs, ...}: {
  home.packages = with pkgs; [
    manix #A Fast Documentation Searcher for Nix
    statix #Lints and suggestions for the nix programming language
    deadnix #Find and remove unused code in .nix source files
    nixpkgs-fmt #Nix code formatter for nixpkgs
    nixpkgs-lint
    nix-update
    nix-doc
    nix-bash-completions
    nix-zsh-completions
    nixos-container
    nixos-generators #A utility for Nixpkgs contributors to check Nixpkgs for common errors
    nh
    nvd
    nix-output-monitor
  ];
}
