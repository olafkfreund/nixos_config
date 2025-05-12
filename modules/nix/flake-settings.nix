{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    settings = {
      # Enable flakes and nix-command by default
      experimental-features = ["nix-command" "flakes"];

      # Accept flake configurations automatically
      accept-flake-config = true;

      # Optimize store to save space
      auto-optimise-store = true;
    };

    # Garbage collection settings
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
}
