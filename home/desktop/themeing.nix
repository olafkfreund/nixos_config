# putting this here cuz i dont know where else to put it
# base08 - red
# base09 - orange
# base0A - yellow
# base0B - green
# base0C - aqua/cyan
# base0D - blue
# base0E - purple
# base0F - brown
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
      package = pkgs.gruvbox-dark-gtk;
      name = "gruvbox-dark";
    };
    cursorTheme.name = "Bibata-Modern-Classic";
    iconTheme = {
      package = pkgs.gruvbox-dark-icons-gtk;
      name = "gruvbox-dark";
    };
    font = {
      name = "JetBrainsMono Nerd Font Medium";
      size = 9;
    };
    gtk3 = {
      extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=1
        '';
      };
    };

    gtk4 = {
      extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=1
        '';
      };
    };
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
  };

  qt = {
    enable = true;
    platformTheme = "gtk3";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };
}