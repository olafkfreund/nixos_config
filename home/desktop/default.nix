{pkgs, ...}: {
  imports = [
    # Enhanced desktop components only (isolated test)
    ./waybar/default.nix
    ./terminals/default.nix  
    ./rofi/default.nix
    ./swaync/default.nix
    
    # Keep essential non-conflicting modules
    ./hyprland/default.nix
    ./theme/default.nix
    ./gaming/default.nix
    ./sound/default.nix
    
    # Commented out to avoid conflicts during isolated test
    # ./plasma/default.nix
    # ./ags/default.nix
    # ./dunst/default.nix
    # ./swaylock/default.nix
    # ./com.nix
    # ./neofetch/default.nix
    # ./kdeconnect/default.nix
    # ./slack/default.nix
    # ./obs/default.nix
    # ./flameshot/default.nix
    # ./kooha/default.nix
    # ./zathura/default.nix
    # ./remotedesktop/default.nix
    # ./evince/default.nix
    # ./lanmouse/default.nix
    # ./walker/default.nix
    # ./obsidian/default.nix
  ];

  home.packages = with pkgs; [
    remmina
    freerdp
  ];
}
