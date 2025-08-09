{ pkgs
, lib
, ...
}: {
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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "olafkfreund" ];
  nix.settings.http-connections = 50;
  nix.settings.warn-dirty = false;
  nix.settings.log-lines = 50;
  nix.settings.sandbox = "relaxed";
  nix.settings.auto-optimise-store = true;
  nix.settings.max-jobs = "auto";
  nix.settings.cores = 0;

  # Binary cache configuration for p620
  nix.settings.trusted-substituters = [
    "http://192.168.1.97:5000" # Use your p620's actual hostname or IP address here
  ];
  nix.settings.trusted-public-keys = [
    "p620-nix-serve:mZR6o5z5KcWeu4PVXgjHA7vb1sHQgRdWMKQt8x3a4rU="
  ];

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
      "jitsi-meet-1.0.8043" # Required for video conferencing
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
