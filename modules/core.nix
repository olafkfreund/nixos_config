_: {
  # Core modules - always loaded on every host
  # These provide essential system functionality
  imports = [
    ./common/default.nix
    ./nix/nix.nix
    ./nix/flake-settings.nix
    ./security/default.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    ./scripts/temp-dashboard.nix

    # System utilities - always useful
    ./system-utils/utils.nix
    ./system-utils/unpack.nix
    ./system-utils/system_util.nix

    # Basic tools
    ./tools/nixpkgs-monitors.nix

    # Basic services that most hosts need
    ./services/default.nix

    # Network stability modules - core networking
    ./services/dns/secure-dns.nix
    ./services/network-stability.nix

    # System optimization modules
    ./system/fstrim-optimization.nix
  ];
}
