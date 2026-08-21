{ pkgs, osConfig }:
# Values shared by every Wayland session in this directory. A plain attrset, not
# a module: each session file imports it in its own `let`, so there are no extra
# options to look up and nothing is added to any host that doesn't import it.
{
  # Wallpaper shared with Stylix (the system sets stylix.image to this same
  # path); swaybg paints it on the bare compositor sessions, which Stylix does not.
  wallpaper = (import ../../../hosts/common/shared-variables.nix).baseTheme.wallpaper;

  # Only laptops auto-suspend on idle; the workstation stays up (RDP / AI host).
  isLaptop = (osConfig.host.class or "") == "laptop";

  # Fixed UK coordinates (London) so gammastep adjusts colour temperature by
  # sun position without pulling in geoclue2.
  geo = "51.5:-0.13";

  # GTK3's GSettings schema dir. GNOME exposes these to its session, but a bare
  # greetd-launched niri/labwc/mango session does not, so unwrapped GTK apps
  # (GIMP, darktable, …) abort with "Settings schema 'org.gtk.Settings.
  # FileChooser' is not installed". GSETTINGS_SCHEMA_DIR is additive — GLib
  # still reads XDG_DATA_DIRS too — so this just makes the GTK schemas findable.
  gtkSchemas = "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}/glib-2.0/schemas";
}
