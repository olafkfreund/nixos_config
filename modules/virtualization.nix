_: {
  # Virtualization and container modules
  # Only load on hosts that run VMs or containers
  imports = [
    ./virt/default.nix
    ./virt/spice.nix
    ./virt/incus.nix
    ./virt/podman.nix
    ./containers/default.nix
  ];
}
