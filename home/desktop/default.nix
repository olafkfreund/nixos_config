{pkgs, ...}: {
  imports = [
    ./plasma/default.nix
    ./ags/default.nix
    ./dunst/default.nix
    ./hyprland/default.nix
    ./swaylock/default.nix
    # ./sway/default.nix
    ./waybar/default.nix
    ./com.nix
    ./terminals/default.nix
    ./rofi/default.nix
    ./theme/default.nix
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
  ];

  home.packages = with pkgs; [
    remmina
    freerdp
  ];
}
