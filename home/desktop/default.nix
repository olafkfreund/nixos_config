{pkgs, ...}: {
  imports = [
    ./plasma/plasma.nix
    ./cosmic/cosmic.nix
    ./scripts.nix
    ./dunst/default.nix
    ./hyprland/default.nix
    #./swaylock/default.nix
    ./waybar/default.nix
    ./com.nix
    ./terminals/default.nix
    ./rofi/rofi.nix
    #./theme/default.nix
  ];

  home.packages = with pkgs; [
    discord
    remmina
    freerdp
  ];

  # GitHub CLI tool
  programs.gh = {
    enable = true;
  };
}
