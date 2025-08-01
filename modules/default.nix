{...}: {
  # Revert to static imports to avoid infinite recursion
  # Performance optimization through conditional imports requires
  # a different architecture that doesn't create circular dependencies
  imports = [
    # Core modules - always loaded
    ./common/default.nix
    ./nix/nix.nix
    ./nix/flake-settings.nix
    ./services/default.nix
    ./security/default.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    ./system-scripts/default.nix
    ./scripts/temp-dashboard.nix
    
    # System utilities - always useful
    ./system-utils/utils.nix
    ./system-utils/unpack.nix
    ./system-utils/system_util.nix
    
    # Tools and monitoring
    ./tools/nixpkgs-monitors.nix
    ./ssh/ssh.nix
    
    # Development modules
    ./ai/default.nix
    ./helpers/helpers.nix
    
    # Email modules
    ./email/default.nix
    
    # Monitoring modules
    ./monitoring/default.nix
    
    # Virtualization modules
    ./virt/default.nix
    ./virt/spice.nix
    ./virt/incus.nix
    ./virt/podman.nix
    ./containers/default.nix
    
    # Cloud tools
    ./cloud/default.nix
    
    # Desktop/program modules
    ./programs/default.nix
    ./fonts/fonts.nix
    ./webcam/default.nix
    ./obsidian/default.nix
    ./office/default.nix
    ./funny/funny.nix
    ./spell/spell.nix
    
    # Desktop environment modules
    ./desktop/default.nix
    ./desktop/wlr/default.nix
    ./desktop/remote/default.nix
    ./desktop/cloud-sync/default.nix
    ./desktop/vnc/default.nix
    ./desktop/gtk/default.nix
    
    # Network stability modules
    ./services/dns/secure-dns.nix
    ./services/network-monitoring.nix
    ./services/network-stability.nix
    
    # System optimization modules
    ./system/fstrim-optimization.nix
    
    # Performance optimization modules (Phase 10.4)
    ./system/resource-manager.nix
    ./networking/performance-tuning.nix
    ./storage/performance-optimization.nix
    ./monitoring/performance-analytics.nix
    ./ai/auto-performance-tuner.nix
    
    # Networking modules
    ./networking/tailscale.nix
  ];
}
