{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.nix) {
    environment.systemPackages =
      [
        pkgs.nurl
        pkgs.nixpkgs-fmt
        pkgs.nil
        pkgs.manix # A Fast Documentation Searcher for Nix
        pkgs.statix # Lints and suggestions for the nix programming language
        pkgs.deadnix # Find and remove unused code in .nix source files
        pkgs.nixpkgs-lint
        pkgs.nix-update
        pkgs.nix-bash-completions
        pkgs.nix-zsh-completions
        pkgs.nixos-container
        pkgs.nh
        pkgs.nvd
        pkgs.nix-output-monitor
        pkgs.nixd
        pkgs.nix-search-cli
        pkgs.alejandra
        pkgs.sops
        pkgs.ssh-to-age
        pkgs.age
      ];
  };
}
