{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  cfg = config.desktop.gnome;
  vars = import ../../../hosts/common/shared-variables.nix;
in
{
  config = mkIf (cfg.enable && cfg.theme.enable) {
    # COSMIC firewall: keep ~/.config/gtk-{3,4}.0/gtk.css free for cosmic-comp's
    # runtime symlink (gtk.css -> ~/.config/gtk-4.0/cosmic/dark.css). With
    # `stylix.targets.gtk.enable = false` system-wide, GNOME themes from
    # gsettings + the GTK theme package on PATH and does not need this file.
    xdg.configFile."gtk-3.0/gtk.css".enable = false;
    xdg.configFile."gtk-4.0/gtk.css".enable = false;

    # Fonts that GNOME-specific bits rely on. Stylix already supplies the
    # mono/sans/serif packages declared in modules/desktop/stylix-theme.nix.
    home.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];

    # Stylix's GNOME target writes the rest of org/gnome/desktop/interface
    # (gtk-theme, icon-theme, cursor-theme + size, font-name,
    # document-font-name, monospace-font-name, color-scheme). Only keep
    # dconf entries here for things Stylix does not manage.
    dconf.settings = {
      "org/gnome/desktop/wm/preferences" = {
        # Stylix doesn't theme the WM titlebar font; follow the Stylix sans
        # so the titlebar matches the rest of the GNOME UI.
        titlebar-font = "${vars.baseTheme.font.sans} Bold ${toString vars.baseTheme.font.sizes.applications}";
      };

      # GNOME Terminal palette — Stylix has no GNOME Terminal target,
      # so wire up the 16 ANSI slots from the active base16 scheme
      # exposed at config.lib.stylix.colors.baseNN. Trade-off: base16
      # only defines the *bright* gruvbox accents (base08..base0F). The
      # normal ANSI slots therefore reuse the bright values too, so the
      # dim/bright distinction other terminals show (e.g. cc241d vs
      # fb4934 for red) collapses here. In return the palette now
      # follows whatever base16Scheme is set in shared-variables.nix
      # — no more silent drift.
      "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
        background-color = "#${config.lib.stylix.colors.base00}";
        foreground-color = "#${config.lib.stylix.colors.base05}";
        palette = with config.lib.stylix.colors; [
          "#${base00}" # 0  black
          "#${base08}" # 1  red
          "#${base0B}" # 2  green
          "#${base0A}" # 3  yellow
          "#${base0D}" # 4  blue
          "#${base0E}" # 5  magenta
          "#${base0C}" # 6  cyan
          "#${base05}" # 7  white
          "#${base03}" # 8  bright black
          "#${base08}" # 9  bright red
          "#${base0B}" # 10 bright green
          "#${base0A}" # 11 bright yellow
          "#${base0D}" # 12 bright blue
          "#${base0E}" # 13 bright magenta
          "#${base0C}" # 14 bright cyan
          "#${base07}" # 15 bright white
        ];
        use-theme-colors = false;
        use-system-font = false;
        font = "Adwaita Mono 11";
        audible-bell = false;
        visual-bell = false;
      };

      # Background/screensaver gradient fallback colors (Stylix manages the
      # wallpaper image but not these solid-color gradient stops).
      "org/gnome/desktop/background" = {
        picture-options = mkDefault "zoom";
        primary-color = mkDefault "#282828";
        secondary-color = mkDefault "#1d2021";
      };

      "org/gnome/desktop/screensaver" = {
        primary-color = mkDefault "#282828";
        secondary-color = mkDefault "#1d2021";
      };
    };
  };
}
