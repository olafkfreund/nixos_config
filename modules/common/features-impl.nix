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
    services = {
      print.enable = cfg.programs.print;
    };

    # Security tools (conditional enables)
    security.onepassword.enable = mkIf cfg.security.enable cfg.security.onepassword;
    security.gnupg.enable = mkIf cfg.security.enable cfg.security.gnupg;

    # Networking (conditional enables)

    # Programs (conditional enables)
    programs = {
      lazygit.enable = cfg.programs.lazygit;
      thunderbird.enable = cfg.programs.thunderbird;
      obsidian.enable = cfg.programs.obsidian;
      office.enable = cfg.programs.office;
      webcam.enable = cfg.programs.webcam;
    };

    # Media tools (conditional enables)
    media.droidcam.enable = cfg.media.droidcam;
  };
}
