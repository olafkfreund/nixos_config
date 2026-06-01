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

      # YAMIS — monochrome icon theme with FollowsColorScheme=true, so the
      # same theme name works for both light and dark polarity (Stylix flips
      # the polarity via dconf; the theme adapts automatically).
      # Falls back to Papirus-Dark / breeze-dark / Cosmic / Adwaita for any
      # icon YAMIS doesn't ship — see pkgs/yet-another-monochrome-icons.
      # Note: use the modern `stylix.icons` namespace; the old
      # `stylix.iconTheme` is deprecated and emits a warning.
      icons = {
        enable = true;
        package = pkgs.yet-another-monochrome-icons;
        dark = "yet-another-monochrome-icon-set";
        light = "yet-another-monochrome-icon-set";
      };

      targets = {
        chromium.enable = false;

        # kmscon: stylix's kmscon target still sets the removed-in-nixpkgs-50
        # `services.kmscon.fonts` option, which now fails the build. We don't
        # theme the Linux text console anyway (Wayland sessions are what
        # matters here), so disable the target until upstream stylix updates.
        kmscon.enable = false;

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
