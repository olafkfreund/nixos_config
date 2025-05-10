{pkgs, ...}: {
  imports = [
    ./plasma/plasma.nix
    ./ags/default.nix
    ./dunst/default.nix
    ./hyprland/hyprland.nix
    ./swaylock/default.nix
    # ./sway/default.nix
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
    ./swaync/default.nix
    ./evince/default.nix
    ./lanmouse/default.nix
    ./walker/default.nix
    ./obsidian/default.nix
    # ./gh/default.nix
  ];

  home.packages = with pkgs; [
    remmina
    freerdp
  ];
}
