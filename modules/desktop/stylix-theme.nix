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

        # COSMIC firewall: Stylix must NOT write ~/.config/gtk-{3,4}.0/gtk.css.
        # cosmic-comp owns that path at runtime (symlinks gtk.css to its own
        # ~/.config/gtk-4.0/cosmic/dark.css). GNOME themes correctly without
        # gtk.css from the GTK theme package referenced in gsettings.
        gtk.enable = false;

        # GNOME target writes org.gnome.desktop.interface/* via gsettings and
        # ships a generated GTK theme package. COSMIC stores its own theme in
        # ~/.config/cosmic/com.system76.CosmicTheme.* and ignores these
        # gsettings keys, so the two desktops stay isolated.
        gnome.enable = true;

        qt = {
          enable = true;
          platform = lib.mkForce "qtct";
        };
      };
    };
  };
}
