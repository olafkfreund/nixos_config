{...}: {
  imports = [
    ./docker.nix
    ./qemu.nix
    ./virtualbox.nix
    ./kubernetes.nix
    ./lxc.nix
  ];
}
