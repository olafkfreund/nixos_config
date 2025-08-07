{
  config,
  pkgs,
  ...
}: {
  # Required packages for proper Thunderbird UI rendering
  home.packages = with pkgs; [
    # GTK theme integration
    gtk3
    gtk4
    gsettings-desktop-schemas
    gnome.adwaita-icon-theme
    gnome.gnome-themes-extra

    # Thunderbird tray integration
    birdtray
  ];

  programs.thunderbird = {
    enable = true;
    package = pkgs.thunderbird-latest-unwrapped;

    profiles.default = {
      settings = {
        # Force GTK theme to Adwaita for better compatibility
        "widget.content.gtk-theme-override" = "Adwaita:dark";

        # Fix menu rendering issues
        "ui.use-xim" = false;
        "widget.disable-native-theme-for-content" = true;
        "layout.css.devPixelsPerPx" = "1.0";

        # Enable hardware acceleration if appropriate
        "layers.acceleration.force-enabled" = true;
      };
    };
  };

  # Environment variables to ensure proper GTK integration
  home.sessionVariables = {
    # Force consistent GTK theming
    GTK_THEME = "Adwaita:dark";

    # Use XDG directories for configuration
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";

    # Disable client-side decorations to prevent rendering issues
    GTK_CSD = "0";

    # Set consistent icon theme
    GTK_ICON_THEME = "Adwaita";
  };

  # Configure GTK settings explicitly
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita";
      package = pkgs.gnome.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.gnome.adwaita-icon-theme;
    };
  };

  # Enable D-Bus for proper integration
  services.dbus.enable = true;
}
