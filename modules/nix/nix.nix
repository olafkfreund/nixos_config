# Test comment to verify pre-commit flake-check hook
{ pkgs
, lib
, ...
}:
with lib;
{
  system.autoUpgrade = {
    enable = true;
    flags = [
      "--no-write-lock-file"
      "--show-trace"
    ];
    dates = "04:00";
    randomizedDelaySec = "45min";
    persistent = true;
    allowReboot = false;
    rebootWindow = {
      lower = "01:00";
      upper = "05:00";
    };
    flake = "github:olafkfreund/nixos_config";
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "olafkfreund" ];
    http-connections = 50;
    warn-dirty = false;
    log-lines = 50;
    sandbox = "relaxed";
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;

    # Maximize cache usage, allow local builds as fallback
    builders-use-substitutes = true;
    substitute = true;
    max-substitution-jobs = 128;
    fallback = true; # Build locally if substitute not available

    # Multi-tier binary cache configuration
    # Priority order: NixOS official → Nix community
    substituters = [
      "https://cache.nixos.org" # Official NixOS cache (always available)
      "https://nix-community.cachix.org" # Community cache
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" # Official NixOS
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" # Nix community
    ];

    # Optional: Add Cachix personal cache (free tier: 5GB storage, unlimited downloads)
    # Sign up at https://cachix.org for free
    # Example: "your-username.cachix.org"
    # To use: uncomment and add your cachix auth token via:
    # $ cachix authtoken YOUR_TOKEN
  };

  # Package permissions - security-focused configuration
  nixpkgs.config = {
    # Allow unfree packages globally (needed for many essential packages)
    allowUnfree = true;
    joypixels.acceptLicense = true;

    # Specific unfree packages (if needed for additional control)
    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "slack-4.36.140"
      ];

    # SECURITY: Only allow specific insecure packages, never global allowInsecure
    # Remove allowInsecure = true for better security
    permittedInsecurePackages = [
      "electron-25.9.0" # Required by some Electron apps
      "electron-29.4.6" # Required by some Electron apps
      "nix-2.15.3" # Required for compatibility
      "olm-3.2.16" # Required for Matrix client
      "python3.12-youtube-dl-2021.12.17" # Required for media tools
    ];
  };

  environment.systemPackages = with pkgs; [
    wget
    home-manager
    gnupg
  ];
}
