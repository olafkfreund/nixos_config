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

      # GNOME Terminal palette — Stylix has no GNOME Terminal target.
      "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
        background-color = "#282828";
        foreground-color = "#ebdbb2";
        palette = [
          "#282828" # black
          "#cc241d" # red
          "#98971a" # green
          "#d79921" # yellow
          "#458588" # blue
          "#b16286" # magenta
          "#689d6a" # cyan
          "#a89984" # white
          "#928374" # bright black
          "#fb4934" # bright red
          "#b8bb26" # bright green
          "#fabd2f" # bright yellow
          "#83a598" # bright blue
          "#d3869b" # bright magenta
          "#8ec07c" # bright cyan
          "#ebdbb2" # bright white
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
