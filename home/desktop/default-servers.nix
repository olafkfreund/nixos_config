{ pkgs, ... }: {
  imports = [
    # ./scripts.nix
    ./terminals/default.nix
    ./terminals.nix
    ./cloud-sync/default.nix
  ];

  # GitHub CLI tool
  programs.gh = {
    enable = true;
  };
}
