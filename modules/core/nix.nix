{
  config,
  lib,
  pkgs,
  ...
}: {
  # This module contains Nix-specific configuration

  # Nix settings optimized for desktop and development use
  nix = {
    settings = {
      # Enable flakes and new commands
      experimental-features = ["nix-command" "flakes"];

      # Performance optimizations
      auto-optimise-store = true;
      max-jobs = "auto";
      cores = 0; # Use all available cores

      # Trust settings
      trusted-users = ["root" "@wheel"];

      # Substituter configuration (this will be overridden by flake.nix)
      substituters = lib.mkDefault [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = lib.mkDefault [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    # Registry for consistency
    registry = {
      nixpkgs.flake = lib.mkDefault {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        ref = "nixos-unstable";
      };
    };
  };

  # NixOS configuration
  nixpkgs.config.allowUnfree = true;

  # System version
  system.stateVersion = lib.mkDefault "24.11";
}
