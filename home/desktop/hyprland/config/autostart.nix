{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    #Start VNC server
    exec-once = wayvnc 0.0.0.0
    # Set cursor theme
    exec-once = hyprctl setcursor Bibata-Modern-Ice 24

    # swww wallpaper
    exec-once = swww init & sleep 0.1 & swww img /home/olafkfreund/Pictures/wallhaven-2yqzd9.jpg --transition-type center
    # Start GNOME Keyring for secure storage of passwords and keys
    exec-once = gnome-keyring-daemon --start --components=secrets

    # exec-once = systemctl --user start graphical-session.target

    # Launch authentication agent for privilege escalation dialogs
    # exec-once = sleep 10 & polkit-kde-authentication-agent-1

    # Start KDE Connect daemon and indicator for device integration
    exec-once = kdeconnectd

    # Update environment variables for proper Wayland integration
    exec-once = dbus-update-activation-environment --systemd --all
    exec-once = systemctl --user import-environment PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

    # Restart XDG desktop portal for proper functionality
    exec-once = sleep 10 && systemctl --user restart xdg-desktop-portal.service

    # Start polkit agent helper
    exec-once = polkit-agent-helper-1

    # Set GNOME desktop interface settings
    exec-once = gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
    exec-once = gsettings set org.gnome.desktop.interface icon-theme "Gruvbox-Material-Dark"
    exec-once = gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Material-Dark"

    # Launch Waybar (top bar)
    exec-once = killall -q waybar;sleep .5 & waybar

    # Start SwayOSD for on-screen display notifications
    exec-once = swayosd-server
    exec-once = sudo swayosd-libinput-backend

    # Launch notification daemon (Dunst)
    #exec-once = killall dunst;sleep .5 & dunst

    # Start KDE Connect CLI
    exec-once = kdeconnect-cli

    # Launch playerctl daemon for media player control
    exec-once = playerctld daemon

    # Launch idle daemon
    exec-once = hypridle

    # Set up clipboard history
    exec-once = wl-paste --type text --watch cliphist store # Store text data
    exec-once = wl-paste --type image --watch cliphist store # Store image data

    # Generate keybinds and exec commands for reference
    # exec-once = $keybinds = $(hyprkeys -bjl | jq '.Binds | map(.Bind + " -> " + .Dispatcher + ", " + .Command)'[] -r)
    # exec-once = $execs = $(hyprkeys -aj | jq '.AutoStart | map("[" + .ExecType + "] " + .Command)'[] -r)
  '';
}
