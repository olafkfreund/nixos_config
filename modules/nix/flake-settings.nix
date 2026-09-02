{ lib, ... }: {
  nix = {
    settings = {
      # Enable flakes and nix-command by default
      experimental-features = [ "nix-command" "flakes" ];

      # Accept flake configurations automatically
      accept-flake-config = true;

      # auto-optimise-store is deliberately NOT set here: it races the in-build
      # collector enabled by min-free/max-free in ./nix.nix and leaves invalid
      # store paths behind. Deduplication happens on a timer instead --
      # `nix.optimise` in ./nix.nix.
    };

    # Garbage collection settings
    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkDefault "--delete-older-than 14d";
    };
  };
}
