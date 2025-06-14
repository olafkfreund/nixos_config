{...}: {
  imports = [
    ./common/default.nix # Import our new common modules
    ./nix/nix.nix
    ./nix/flake-settings.nix # New module for flake settings
    ./fonts/fonts.nix
    ./programs/default.nix
    ./services/default.nix
    ./security/default.nix
    ./virt/default.nix
    ./virt/spice.nix
    ./virt/incus.nix
    ./virt/podman.nix
    ./pkgs/default.nix
    ./overlays/default.nix
    ./system-scripts/default.nix
    # ./nix-index/default.nix
    ./containers/default.nix
    ./applications/default.nix # Application modules
    ./cloud/default.nix
    ./ssh/ssh.nix
    ./system-utils/utils.nix
    ./system-utils/unpack.nix
    ./system-utils/system_util.nix
    ./ai/chatgpt.nix
    ./funny/funny.nix
    ./spell/spell.nix
    ./helpers/helpers.nix
    ./webcam/default.nix
    ./desktop/default.nix # Qt platform theme configuration
    ./desktop/wlr/default.nix
    ./desktop/remote/default.nix
    ./desktop/wldash/default.nix
    ./desktop/cloud-sync/default.nix
    ./desktop/vnc/default.nix
    ./desktop/gtk/default.nix
    # ./desktop/electron-config.nix
    ./obsidian/default.nix
    ./office/default.nix
    # ./intune-portal/default.nix

    # Network stability modules
    ./services/dns/secure-dns.nix
    ./services/network-monitoring.nix
    ./services/network-stability.nix
  ];
}
