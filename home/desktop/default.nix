{
  pkgs,
  ...
}: {
  imports = [
    ./plasma/plasma.nix
    ./ags/default.nix
    ./dunst/default.nix
    ./hyprland/default.nix
    ./swaylock/default.nix
    ./sway/default.nix
    ./waybar/default.nix
    ./com.nix
    ./terminals/default.nix
    ./rofi/rofi.nix
    ./theme/default.nix
    ./com.nix
    ./neofetch/default.nix
    ./gaming/default.nix
    ./sound/default.nix
    ./kdeconnect/default.nix
    ./slack/default.nix
    ./obs/default.nix
    ./flameshot/default.nix
    ./kooha/default.nix
    ./zathura/default.nix
    ./remotedesktop/default.nix
    ./gh/default.nix
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
