{pkgs, ...}: {
  imports = [
    ./cargo.nix
    ./python.nix
    ./ansible.nix
    ./vscode.nix
    ./go.nix
    ./java.nix
    ./lua.nix
    ./nix.nix
    ./shell.nix
    ./devbox.nix
    ./nodejs.nix
    ./github.nix
    ./nvim.nix
    # ./emacs.nix
    ./zed.nix
    ./containers.nix
    ./distrobox.nix
  ];
  home.packages = [
    (import ./cursor-code.nix { inherit pkgs;})
  ];
}
