{ pkgs, ... }: {
  imports = [
    # Desktop components
    ./terminals/default.nix
    ./terminal-apps-desktop-entries.nix

    # Core desktop modules
    ./theme/default.nix
    ./gaming/default.nix
    ./sound/default.nix

    # Desktop modules
    ./plasma/default.nix
    ./com.nix
    ./neofetch/default.nix
    ./kdeconnect/default.nix
    ./slack/default.nix
    ./obs/default.nix
    ./flameshot/default.nix
    ./screenshots/wayland-native.nix
    ./kooha/default.nix
    ./zathura/default.nix
    ./remotedesktop/default.nix
    ./evince/default.nix
    ./lanmouse/default.nix
    ./obsidian/default.nix
    ./proton/default.nix # Proton applications suite (optional)
    ./gnome # GNOME desktop environment (optional)
  ];
}
