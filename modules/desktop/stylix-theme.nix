{ pkgs
, lib
, config
, ...
}:
let
  vars = import ../../hosts/common/shared-variables.nix;
in
{
  config = {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      polarity = "dark";
      autoEnable = true;
      base16Scheme =
        "${pkgs.base16-schemes}/share/themes/${vars.baseTheme.scheme}.yaml";
      image = vars.baseTheme.wallpaper;

      fonts = {
        monospace = {
          # adwaita-fonts ships AdwaitaMono-{Regular,Bold,Italic,BoldItalic}.ttf.
          # gnome-themes-extra (used previously) ships zero font files — that
          # was a silent misconfiguration.
          package = pkgs.adwaita-fonts;
          name = vars.baseTheme.font.mono;
        };
        sansSerif = {
          package = pkgs.noto-fonts;
          name = vars.baseTheme.font.sans;
        };
        serif = {
          package = pkgs.noto-fonts;
          name = vars.baseTheme.font.serif;
        };
        sizes = vars.baseTheme.font.sizes;
      };

      opacity = vars.baseTheme.opacity;

      cursor = {
        name = vars.baseTheme.cursor.name;
        package = pkgs.bibata-cursors;
        size = vars.baseTheme.cursor.size;
      };

      targets = {
        chromium.enable = false;

        # COSMIC's GTK theme sync is disabled on this fleet, so cosmic-comp
        # does NOT clobber ~/.config/gtk-{3,4}.0/gtk.css at runtime. Stylix
        # can own that file safely and theme GTK3 / non-libadwaita GTK4 apps
        # everywhere. libadwaita apps still ignore third-party themes by
        # upstream policy regardless of gtk.css contents.
        gtk.enable = true;

        # GNOME target writes org.gnome.desktop.interface/* via gsettings and
        # ships a generated GTK theme package. COSMIC stores its own theme in
        # ~/.config/cosmic/com.system76.CosmicTheme.* and ignores these
        # gsettings keys, so the two desktops stay isolated.
        gnome.enable = config.host.class != "headless-rdp";

        qt = {
          enable = true;
          platform = lib.mkForce "qtct";
        };
      };
    };
  };
}
