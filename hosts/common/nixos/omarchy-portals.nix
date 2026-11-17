# The Hyprland portal preferences, as the mutable file held them before Flea (#2694) took it over:
# Hyprland's portal for everything it implements (screen sharing included), GTK for the rest
# (the file picker), and gnome-keyring for secrets.
_: {
  home-manager.users.olafkfreund.xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text = ''
    [preferred]
    default=hyprland;gtk
    org.freedesktop.impl.portal.Secret=gnome-keyring
  '';
}
