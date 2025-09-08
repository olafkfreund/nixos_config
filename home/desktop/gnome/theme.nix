{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.desktop.gnome;
in {
  config = mkIf (cfg.enable && cfg.theme.enable) {
    # GTK theming with Gruvbox colors
    gtk = {
      enable = true;
      
      theme = {
        package = mkDefault pkgs.gruvbox-gtk-theme;
        name = mkDefault (if cfg.theme.variant == "dark" then "Gruvbox-Dark-BL" else "Gruvbox-Light-BL");
      };

      iconTheme = {
        package = mkDefault pkgs.gruvbox-plus-icons;
        name = mkDefault "Gruvbox-Plus-Dark";
      };

      cursorTheme = {
        package = mkDefault pkgs.bibata-cursors;
        name = mkDefault "Bibata-Modern-Classic";
        size = mkDefault 16;
      };

      font = {
        name = mkDefault "Inter";
        size = mkDefault 11;
      };

      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = cfg.theme.variant == "dark";
      };

      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = cfg.theme.variant == "dark";
      };
    };

    # Ensure required fonts are available
    home.packages = with pkgs; [
      inter
      (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
    ];

    # GNOME-specific theming via dconf
    dconf.settings = mkIf cfg.theme.enable {
      "org/gnome/desktop/interface" = {
        gtk-theme = if cfg.theme.variant == "dark" then "Gruvbox-Dark-BL" else "Gruvbox-Light-BL";
        icon-theme = "Gruvbox-Plus-Dark";
        cursor-theme = "Bibata-Modern-Classic";
        cursor-size = 16;
        font-name = "Inter 11";
        document-font-name = "Inter 11";
        monospace-font-name = "JetBrainsMono Nerd Font 10";
        color-scheme = if cfg.theme.variant == "dark" then "prefer-dark" else "prefer-light";
      };

      "org/gnome/desktop/wm/preferences" = {
        titlebar-font = "Inter Bold 11";
      };

      # Terminal theming (GNOME Terminal)
      "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
        background-color = "#282828";
        foreground-color = "#ebdbb2";
        palette = [
          "#282828"  # black
          "#cc241d"  # red
          "#98971a"  # green  
          "#d79921"  # yellow
          "#458588"  # blue
          "#b16286"  # magenta
          "#689d6a"  # cyan
          "#a89984"  # white
          "#928374"  # bright black
          "#fb4934"  # bright red
          "#b8bb26"  # bright green
          "#fabd2f"  # bright yellow
          "#83a598"  # bright blue
          "#d3869b"  # bright magenta
          "#8ec07c"  # bright cyan
          "#ebdbb2"  # bright white
        ];
        use-theme-colors = false;
        use-system-font = false;
        font = "JetBrainsMono Nerd Font 10";
        audible-bell = false;
        visual-bell = false;
      };

      # Set Gruvbox wallpaper if available
      "org/gnome/desktop/background" = {
        picture-uri = "file://${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Dark-BL/wallpaper.jpg";
        picture-uri-dark = "file://${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Dark-BL/wallpaper.jpg";
        picture-options = "zoom";
        primary-color = "#282828";
        secondary-color = "#1d2021";
      };

      "org/gnome/desktop/screensaver" = {
        picture-uri = "file://${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Dark-BL/wallpaper.jpg";
        primary-color = "#282828";
        secondary-color = "#1d2021";
      };
    };

    # Stylix integration for system-wide theming
    stylix = mkIf (hasAttr "stylix" config) {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
      image = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/lunik1/gruvbox-material-gtk/main/wallpapers/gruvbox-dark-rainbow.png";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
      
      fonts = {
        serif = {
          package = pkgs.inter;
          name = "Inter";
        };
        sansSerif = {
          package = pkgs.inter;
          name = "Inter";
        };
        monospace = {
          package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
          name = "JetBrainsMono Nerd Font";
        };
        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };

    # Custom CSS for GNOME applications (if needed)
    home.file.".config/gtk-3.0/gtk.css".text = ''
      /* Custom Gruvbox styling */
      .titlebar {
        background: #282828;
        color: #ebdbb2;
      }

      .sidebar {
        background: #32302f;
      }

      .view {
        background: #282828;
        color: #ebdbb2;
      }

      /* Dark variant specific */
      @define-color theme_fg_color #ebdbb2;
      @define-color theme_bg_color #282828;
      @define-color theme_selected_bg_color #458588;
      @define-color theme_selected_fg_color #ebdbb2;
      @define-color insensitive_bg_color #3c3836;
      @define-color insensitive_fg_color #928374;
      @define-color insensitive_base_color #32302f;
      @define-color theme_unfocused_fg_color #a89984;
      @define-color theme_unfocused_bg_color #32302f;
      @define-color theme_unfocused_base_color #282828;
      @define-color theme_unfocused_selected_bg_color #458588;
      @define-color theme_unfocused_selected_fg_color #ebdbb2;
      @define-color borders #504945;
      @define-color unfocused_borders #3c3836;
    '';
  };
}