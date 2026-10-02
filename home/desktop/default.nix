{ ... }: {
  imports = [
    # Desktop components
    ./terminals/default.nix
    ./terminal-apps-desktop-entries.nix
    ./chrome-profiles.nix

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
    ./aerion/default.nix
    ./flameshot/default.nix
    ./screenshots/wayland-native.nix
    ./omareel/default.nix
    ./zathura/default.nix
    ./remotedesktop/default.nix
    ./evince/default.nix
    ./lanmouse/default.nix
    ./obsidian/default.nix
    ./proton/default.nix # Proton applications suite (optional)
    ./gnome # GNOME desktop environment (optional)
  ];
}
