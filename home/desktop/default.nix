{pkgs, ...}: {
  imports = [
     ./plasma/plasma.nix
     #./cosmic/cosmic.nix
     ./scripts.nix
     ./dunst/default.nix
     ./hyprland/default.nix
     ./swaylock/default.nix
     ./waybar/default.nix
     ./com.nix
     ./terminals/default.nix
     ./rofi/rofi.nix
     ./theme/default.nix
     ./com.nix
     ./terminals.nix
     ./neofetch/default.nix
     ./gnome/default.nix
     ./wlr/default.nix
     ./gaming/default.nix
     ./sound/default.nix
     #./mail/default.nix
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
