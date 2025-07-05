{
  config,
  lib,
  ...
}: {
  options.modules.system.performance = {
    enable = lib.mkEnableOption "system performance optimizations";

    binaryCache = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable binary cache optimization";
      };

      extraCaches = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional binary caches to use";
        example = ["https://devenv.cachix.org"];
      };

      extraTrustedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional trusted public keys";
        example = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
      };
    };

    garbageCollection = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic garbage collection";
      };

      frequency = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "How often to run garbage collection";
        example = "daily";
      };

      deleteOlderThan = lib.mkOption {
        type = lib.types.str;
        default = "30d";
        description = "Delete store paths older than this";
        example = "7d";
      };
    };

    buildOptimization = {
      maxJobs = lib.mkOption {
        type = lib.types.either lib.types.int (lib.types.enum ["auto"]);
        default = "auto";
        description = "Maximum number of build jobs";
      };

      cores = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Number of CPU cores to use (0 = all available)";
      };
    };
  };

  config = lib.mkIf config.modules.system.performance.enable {
    nix = {
      settings = {
        # Binary cache configuration
        substituters = lib.mkIf config.modules.system.performance.binaryCache.enable ([
            "https://cache.nixos.org/"
            "https://nix-community.cachix.org"
            "https://nixpkgs-unfree.cachix.org"
          ]
          ++ config.modules.system.performance.binaryCache.extraCaches);

        trusted-public-keys = lib.mkIf config.modules.system.performance.binaryCache.enable ([
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt="
          ]
          ++ config.modules.system.performance.binaryCache.extraTrustedKeys);

        # Build optimization
        max-jobs = config.modules.system.performance.buildOptimization.maxJobs;
        cores = config.modules.system.performance.buildOptimization.cores;

        # Enable modern Nix features
        experimental-features = ["nix-command" "flakes"];

        # Store optimization
        auto-optimise-store = true;

        # Build sandbox for security and reproducibility
        sandbox = true;

        # Allow unfree packages
        allow-unfree = true;

        # Warn about dirty git repos
        warn-dirty = false;
      };

      # Garbage collection
      gc = lib.mkIf config.modules.system.performance.garbageCollection.enable {
        automatic = true;
        dates = config.modules.system.performance.garbageCollection.frequency;
        options = "--delete-older-than ${config.modules.system.performance.garbageCollection.deleteOlderThan}";
      };

      # Store optimization
      optimise = {
        automatic = true;
        dates = ["03:45"]; # Run during low usage hours
      };
    };

    # System performance tweaks
    boot.kernel.sysctl = {
      # Memory management
      "vm.swappiness" = 10; # Reduce swapping
      "vm.dirty_ratio" = 6; # Start background writeback at 6%
      "vm.dirty_background_ratio" = 3; # Start writeback at 3%

      # Network performance
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_rmem" = "4096 12582912 16777216";
      "net.ipv4.tcp_wmem" = "4096 12582912 16777216";
    };

    # Systemd service optimizations
    systemd.extraConfig = ''
      DefaultTimeoutStopSec=10s
      DefaultLimitNOFILE=1048576
    '';

    # Log management to prevent disk filling
    services.journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=1month
      ForwardToSyslog=no
    '';

    # Validation
    assertions = [
      {
        assertion = config.modules.system.performance.buildOptimization.maxJobs > 0;
        message = "Build optimization max-jobs must be greater than 0";
      }
      {
        assertion = config.modules.system.performance.buildOptimization.cores > 0;
        message = "Build optimization cores must be greater than 0";
      }
      {
        assertion = config.modules.system.performance.garbageCollection.enable -> (lib.hasInfix "d" config.modules.system.performance.garbageCollection.deleteOlderThan);
        message = "Garbage collection deleteOlderThan must specify a time period (e.g., '30d', '7 days')";
      }
    ];

    # Helpful warnings
    warnings = [
      (lib.mkIf (config.modules.system.performance.buildOptimization.maxJobs > 8) ''
        Build max-jobs is set to ${toString config.modules.system.performance.buildOptimization.maxJobs}.
        Very high values may cause system instability or excessive memory usage.
      '')
      (lib.mkIf (!config.modules.system.performance.garbageCollection.enable) ''
        Garbage collection is disabled. The Nix store will grow indefinitely.
        Consider enabling it to manage disk usage.
      '')
    ];
  };
}
