{pkgs, ...}: {
  imports = [
    ./vscode.nix
    ./nvim.nix
    # ./emacs.nix
    ./zed.nix
    ./containers.nix
    ./distrobox.nix
  ];
  home.packages = [
    (import ./cursor-code.nix { inherit pkgs;})
    pkgs.distrobox-tui
  ];
}
