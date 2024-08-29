{pkgs, ...}: {
  imports = [
    ./vscode.nix
    ./nvim.nix
    # ./emacs.nix
    ./zed.nix
    ./containers.nix
    ./distrobox.nix
    ./cursor-code.nix
  ];
}
