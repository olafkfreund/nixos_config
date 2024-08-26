{ pkgs, ... }: {
  imports = [
    ./plasma/plasma.nix
    # ./scripts.nix
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
    ./wlr/default.nix
    ./gaming/default.nix
    ./sound/default.nix
    ./office/default.nix
    ./webcam/default.nix
    ./obsidian/default.nix
    ./kdeconnect/default.nix
    ./cloud-sync/default.nix
    ./slack/default.nix
    ./obs/default.nix
    ./wldash/default.nix
    ./osd/default.nix
    ./flameshot/default.nix
    ./gnome/default.nix
  ];

  home.packages = with pkgs; [
    remmina
    freerdp

  ];
  # home.file.".xprofile".source = ../../modules/services/dwm/x11/xprofile;
  # home.file.".xinitrc".source = ../../modules/services/dwm/x11/xinitrc;
  # home.file.".Xresources_dwm" = {
  #   enable = true;
  #   source = ../../modules/services/dwm/x11/xresources;
  # };

  # GitHub CLI tool
  programs.gh = {
    enable = true;
  };
}
