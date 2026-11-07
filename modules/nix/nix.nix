{ config
, pkgs
, lib
, ...
}:
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
    flake = "github:olafkfreund/nixos_config";
  };

  # A failed github: fetch falls back to a stale cached flake (#2409); skip the night instead.
  # (only with auto-upgrade on: a host that turns it off, like p510, would get a unit with no ExecStart, #2709)
  systemd.services.nixos-upgrade = lib.mkIf config.system.autoUpgrade.enable {
    serviceConfig.ExecCondition =
      "${pkgs.curl}/bin/curl -sfI -o /dev/null --max-time 20 --retry 5 --retry-delay 30 --retry-all-errors https://api.github.com";
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "olafkfreund" ];
    http-connections = 50;
    warn-dirty = false;
    log-lines = 50;
    sandbox = "relaxed";
    # auto-optimise-store is deliberately NOT set. It deduplicates by hardlink
    # immediately after each build, which races the in-build garbage collector
    # that min-free/max-free below enables: the collector deletes a path while
    # the optimiser is linking into it, and the build dies with
    #   renaming "/nix/store/.tmp-link-...": No such file or directory
    #   error: path '...' is required, but there is no substituter that can build it
    # -- leaving genuinely invalid store paths behind. It cost p620 a rebuild and
    # one corrupted path (zerovec-derive) on 2026-09-02. nix.optimise.automatic
    # below does the same deduplication on a timer, when nothing else is running.
    max-jobs = "auto";
    cores = 0;

    # Proactive garbage collection: when free space on the nix store drops below
    # min-free, nix runs GC *during* builds until max-free is reached. This is the
    # real safeguard against the store filling to 100% — which deadlocks the
    # periodic nix-gc.service (a full disk can't write the DB to delete anything).
    # p510 filled up over ~11 days because only the weekly timer existed. 10G floor.
    # mkDefault: a host that builds VMs needs a floor sized to its disk, and
    # services.nixarchy-runner sets one (#1809).
    min-free = lib.mkDefault (10 * 1024 * 1024 * 1024); # 10 GiB — trigger GC when below
    max-free = lib.mkDefault (50 * 1024 * 1024 * 1024); # 50 GiB — GC up to this once triggered

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
      "https://devenv.cachix.org"
      "https://nixarchy.cachix.org"
      "https://hyprland.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" # Official NixOS
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" # Nix community
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixarchy.cachix.org-1:05JOuIlsQOWY2/5DQMq7JEA1hwlhgvmMWowMfka8mMM="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      # Per-host signing keys (#2758); the private halves are agenix secrets on p620 and razer.
      "p620-nix-1:hqZIIrJ1DQAb3yBFhxW5ww6DV0XG9NBxQY7E0yyPoH8="
      "razer-nix-1:5C9bEvpGznTuMVhzQ0yzZR6HKMwdWEjfjh+pC2lW0aw="
    ];
  };

  # Store deduplication on a timer instead of after every build.
  #
  # Replaces `nix.settings.auto-optimise-store`, which raced the in-build
  # collector (see the note above). Same hardlinking, same saving -- it was
  # already reclaiming 18.8 GiB on p510 -- but run when it cannot collide with
  # a build's own paths being deleted underneath it.
  nix.optimise = {
    automatic = true;
    dates = [ "Sun 05:00" ];
  };

  # Package permissions - security-focused configuration
  nixpkgs.config = {
    # Allow unfree packages globally (needed for many essential packages)
    allowUnfree = true;
    joypixels.acceptLicense = true;

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
