{pkgs, ...}: {
  imports = [
    ./cargo.nix
    ./python.nix
    ./ansible.nix
    ./go.nix
    ./java.nix
    ./lua.nix
    ./nix.nix
    ./shell.nix
    ./devbox.nix
    ./nodejs.nix
    ./github.nix
  ];
}