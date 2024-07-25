{ pkgs, ... }: {
  imports = [
    ./scripts.nix
    ./swaylock/default.nix
    ./terminals/default.nix
    ./theme/default.nix
    ./com.nix
    ./terminals.nix
    ./neofetch/default.nix
    ./wlr/default.nix
    ./sound/default.nix
    #./mail/default.nix
    ./webcam/default.nix
    ./cloud-sync/default.nix
    ./wldash/default.nix
    ./osd/default.nix
  ];
  home.packages = with pkgs; [
    remmina
    freerdp
  ];

  # GitHub CLI tool
  programs.gh = {
    enable = true;
  };
}
