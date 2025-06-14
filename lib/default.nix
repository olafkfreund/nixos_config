{
  inputs,
  nixpkgs,
  lib,
}: let
  # Import all library functions
  hostBuilders = import ./host-builders.nix {inherit inputs nixpkgs lib;};
  profiles = import ./profiles.nix {inherit lib;};
  hardware = import ./hardware.nix {inherit lib;};
  utils = import ./utils.nix {inherit lib;};
in
  # Merge all library functions into a single namespace
  hostBuilders
  // profiles
  // hardware
  // utils
  // {
    # Re-export commonly used lib functions for convenience
    inherit (lib) mkIf mkMerge mkOption mkEnableOption types;
  }
