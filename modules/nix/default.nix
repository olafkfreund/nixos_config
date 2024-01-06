
{ self, config, pkgs, ... }: {


  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-23.11";
  };

  nix = {
    settings = {
      allowed-users = [ "@wheel" "olafkfreund" ];
      auto-optimise-store = true;

      experimental-features = [
        "flakes"
        "nix-command"
        "repl-flake"

      ];

      sandbox =
        "relaxed"; # if set to true, This enforces strict sandboxing, which is the default and most secure mode for building and running Nix packages

      trusted-users = [
        "olafkfreund"
        "@wheel"
        "root"

      ];

      # Avoid unwanted garbage collection when using nix-direnv
      keep-derivations = true;
      keep-outputs = true;
      warn-dirty = false;
      tarball-ttl = 300;
      trusted-substituters = [ "http://cache.nixos.org" ];
      substituters = [ "http://cache.nixos.org" ];

    };

    # extraOptions = "builders-use-substitutes";
    # extraOptions = "experimental-features = nix-command flakes";
    # package = pkgs.nixUnstable; # Keep this if you want to use nixUnstable, otherwise replace with the appropriate nix version

    # Lower the priority of Nix builds to not disturb other processes.
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedPriority = 7;

    gc = {
      automatic = true;
      dates = "weekly";
      randomizedDelaySec = "14m";
      options = "--delete-older-than 2d";
    };

  };

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.allowInsecure = true;
    nixpkgs.config.joypixels.acceptLicense = true;
    nixpkgs.config.permittedInsecurePackages = [ "electron-25.9.0" ];


    environment.systemPackages = with pkgs; [
      wget
      nixos-container
      nixos-generators
      nix-zsh-completions
      nix-bash-completions
      ];
}
