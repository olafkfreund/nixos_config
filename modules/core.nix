{ ... }: {
  # Core modules - always loaded on every host
  # These provide essential system functionality
  imports = [
    ./common/default.nix
    ./nix/nix.nix
    ./nix/flake-settings.nix
    ./security/default.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    ./system-scripts/default.nix
    ./scripts/temp-dashboard.nix

    # System utilities - always useful
    ./system-utils/utils.nix
    ./system-utils/unpack.nix
    ./system-utils/system_util.nix

    # Basic tools and SSH
    ./tools/nixpkgs-monitors.nix
    ./ssh/ssh.nix

    # Basic services that most hosts need
    ./services/default.nix

    # Network stability modules - core networking
    ./services/dns/secure-dns.nix
    ./services/network-monitoring.nix
    ./services/network-stability.nix

    # Networking modules
    ./networking/tailscale.nix

    # System optimization modules
    ./system/fstrim-optimization.nix
  ];
}
