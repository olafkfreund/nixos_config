{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features;
in
{
  imports = [
    ./features.nix
  ];

  # Optimized config - reduced mkMerge complexity for better performance
  config = {
    # Baseline tools available on any host enabling features.development.
    # Without this, hosts with development features but no other package-set
    # trigger would lack git/curl/jq at the system level.
    environment.systemPackages = mkIf cfg.development.enable [
      pkgs.git
      pkgs.curl
      pkgs.jq
    ];

    # Development tools (conditional enables)

    # Modules configuration
    modules = {
      containers.docker.enable = mkIf cfg.virtualization.enable cfg.virtualization.docker;
    };

    # Services configuration
    # Networking (conditional enables)

  };
}
