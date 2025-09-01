# Advanced Caching Strategy for Maximum Performance
{ config, lib, pkgs, ... }:
with lib; {
  # Evaluation cache configuration
  nix.settings = {
    # Enable experimental eval-cache for massive speedup
    experimental-features = [ "nix-command" "flakes" "eval-cache" ];
    
    # Aggressive evaluation caching
    eval-cache = mkDefault true;
    
    # Optimize store and build performance  
    max-jobs = mkDefault "auto";
    cores = mkDefault 0; # Use all cores
    
    # Advanced binary cache configuration
    substituters = [
      # Prioritize fastest caches first
      "http://192.168.1.97:5000"  # Your P620 local cache
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      # Specialized caches for heavy packages
      "https://cuda-maintainers.cachix.org"
      "https://hyprland.cachix.org"
    ];
    
    # Keep intermediate build results
    keep-outputs = mkDefault true;
    keep-derivations = mkDefault true;
    keep-failed = mkDefault false; # Don't keep failed builds
    
    # Optimize for multi-core evaluation
    system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    
    # Build result caching
    builders-use-substitutes = mkDefault true;
    
    # Connection optimizations
    connect-timeout = 5;
    download-attempts = 3;
    
    # Store optimization
    auto-optimise-store = mkDefault true;
    
    # Massive parallelization for large configs
    max-substitution-jobs = mkDefault 16;
  };
  
  # Enable periodic store optimization
  nix.optimise = {
    automatic = mkDefault true;
    dates = [ "03:45" ]; # Run during low-usage time
  };
  
  # Garbage collection optimization
  nix.gc = {
    automatic = mkDefault true;
    dates = "weekly";
    options = "--delete-older-than 30d";
    
    # Keep recent generations for fast rollback
    persistent = mkDefault true;
  };

  # Build hook for cache warming
  nix.buildMachines = mkIf (config.networking.hostName != "p620") [
    {
      hostName = "p620";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [];
    }
  ];
  
  # Evaluation cache directory optimization
  environment.variables = {
    NIX_EVAL_CACHE_SIZE = "1000000"; # 1M cache entries
    NIX_EVAL_CACHE_TTL = "86400";    # 24-hour TTL
  };
  
  # Filesystem optimization for Nix store
  fileSystems."/nix" = mkIf (config.fileSystems ? "/nix") {
    options = [ "noatime" "compress=zstd" ]; # Optimize for performance
  };
}