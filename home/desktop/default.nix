{pkgs, ...}: {
  imports = [
    ./plasma/plasma.nix
    #./gnome.nix
    #./awesome/awsome.nix
    #./qtile/qtile.nix
    #./sway/sway.nix
    #./bspwm/bspwm.nix
    #./wallpaper.nix
    #./hyprland/hyprl_config.nix
    #./hyprland/hyprland.nix
    ./com.nix
    ./terminals/default.nix
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
