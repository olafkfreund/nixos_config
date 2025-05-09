{pkgs, ...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # Core system services and environment
    exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE WAYLAND_DEBUG NO_XDG_ICON_WARNING NIXOS_OZONE_WL
    exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE WAYLAND_DEBUG NO_XDG_ICON_WARNING NIXOS_OZONE_WL

    # Restart XDG Portal early to ensure proper protocol handling
    exec-once = systemctl --user stop xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    exec-once = sleep 1 && systemctl --user start xdg-desktop-portal xdg-desktop-portal-hyprland

    # Start essential background services
    exec-once = gnome-keyring-daemon --start --components=secrets

    # Launch proper authentication agent with correct Nix store path
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1

    # Set theme and appearance
    exec-once = hyprctl setcursor Bibata-Modern-Ice 24
    exec-once = gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
    exec-once = gsettings set org.gnome.desktop.interface icon-theme "Gruvbox-Material-Dark"
    exec-once = gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Material-Dark"

    # Start wallpaper service with error handling
    exec-once = swww query || swww init && swww img /home/olafkfreund/Pictures/wallhaven-2yqzd9.jpg --transition-type center

    # Start VNC server (only if needed)
    exec-once = wayvnc 0.0.0.0

    # Start device connectivity services
    exec-once = kdeconnectd
    exec-once = kdeconnect-cli

    # Restart services that need portal integration
    exec-once = sleep 2 && systemctl --user restart xdg-desktop-portal.service

    # Start UI components
    exec-once = waybar

    # Start media and OSD services
    exec-once = swayosd-server
    exec-once = sudo swayosd-libinput-backend
    exec-once = playerctld daemon

    # Start idle management
    exec-once = hypridle

    # Set up clipboard functionality
    exec-once = wl-paste --type text --watch cliphist store
    exec-once = wl-paste --type image --watch cliphist store

    # Log available keybinds and commands (moved to end to avoid startup delays)
    exec-once = $keybinds = $(hyprkeys -bjl | jq '.Binds | map(.Bind + " -> " + .Dispatcher + ", " + .Command)'[] -r)
    exec-once = $execs = $(hyprkeys -aj | jq '.AutoStart | map("[" + .ExecType + "] " + .Command)'[] -r)

    #Start the usal applications
    exec-once = foot --title "Terminal" --exec "zsh"
    exec-once = vesktop
    exec-once = spotify
    exec-once = thunderbird
    exec=once = google-chrome-stable
    exec=once = 1password
  '';
}
