_: {
  imports = [
    # ./scripts.nix
    ./terminals/default.nix
    ./cloud-sync/default.nix
  ];

  # GitHub CLI tool
  programs.gh = {
    enable = true;
  };
}
