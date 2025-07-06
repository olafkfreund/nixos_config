{pkgs, ...}: {
  imports = [
    # Enhanced desktop components
    ./waybar/default.nix
    ./terminals/default.nix  
    ./rofi/default.nix
    ./swaync/default.nix
    
    # Core desktop modules (now enhanced)
    ./hyprland/default.nix
    ./theme/default.nix
    ./gaming/default.nix
    ./sound/default.nix
    
    # Re-enabled desktop modules (enhanced configs take precedence)
    ./plasma/default.nix
    ./ags/default.nix
    ./dunst/default.nix
    ./swaylock/default.nix
    ./com.nix
    ./neofetch/default.nix
    ./kdeconnect/default.nix
    ./slack/default.nix
    ./obs/default.nix
    ./flameshot/default.nix
    ./kooha/default.nix
    ./zathura/default.nix
    ./remotedesktop/default.nix
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
