{
  inputs,
  pkgs,
  config,
  ...
}: {
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 14;
  };
  gtk = {
    enable = true;
    theme = {
      name = "Gruvbox-Dark-B-LB";
    };
    cursorTheme.name = "Bibata-Modern-Classic";
    iconTheme = {
      name = "Gruvbox-Plus-Dark";
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=true
        gtk-cursor-theme-size=24
        gtk-decoration-layout=icon:minimize,maximize,close
        gtk-enable-animations=true
        gtk-modules=colorreload-gtk-module:window-decorations-gtk-module
        gtk-primary-button-warps-slider=false
        gtk-xft-dpi=98304
      '';
    };

    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=true
        gtk-cursor-theme-size=24
        gtk-decoration-layout=icon:minimize,maximize,close
        gtk-enable-animations=true
        gtk-modules=colorreload-gtk-module:window-decorations-gtk-module
        gtk-primary-button-warps-slider=false
        gtk-xft-dpi=98304
      '';
    };
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt6;
    };
  };
  xdg.configFile = {
    "gtk-4.0/assets".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-4.0/assets";
    "gtk-4.0/gtk.css".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-4.0/gtk.css";
    "gtk-4.0/gtk-dark.css".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-4.0/gtk-dark.css";
    "gtk-3.0/assets".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-3.0/assets";
    "gtk-3.0/gtk.css".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-3.0/gtk.css";
    "gtk-3.0/gtk-dark.css".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-3.0/gtk-dark.css";
    "gtk-2.0/.gtkrc-2.0".source = "/home/olafkfreund/.themes/Gruvbox-Dark-B-LB/gtk-2.0/gtkrc.hidpi";
  };
}
