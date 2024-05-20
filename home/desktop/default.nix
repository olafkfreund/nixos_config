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
<<<<<<< HEAD
=======
     ./themeing.nix
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
     #./theme/default.nix
     ./com.nix
     ./terminals.nix
     ./neofetch/default.nix
     ./gnome/default.nix
     ./wlr/default.nix
     ./gaming/default.nix
     ./sound/default.nix
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
