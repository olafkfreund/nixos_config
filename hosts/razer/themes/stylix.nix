{pkgs, ...}: {
  # Stylix theming
  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    image = ./wallhaven-2yqzd9.jpg;

    # Font configuration
    fonts = {
      monospace = {
        # Use the specific nerd-fonts package to ensure proper icons
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
    };

    # Font sizes (adjusted for better readability)
    fonts.sizes = {
      applications = 12;
      terminal = 13;
      desktop = 12;
      popups = 12;
    };

    # Opacity settings
    opacity = {
      desktop = 1.0;
      terminal = 0.95;
      popups = 0.95;
    };

    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors; # You need to add this line
      size = 26;
    };

    # Exclude specific targets
    targets.chromium.enable = false; # Exclude browser theming
  };

  # gtk = {
  #   iconTheme = {
  #     name = "Papirus-Dark";
  #     package = pkgs.papirus-icon-theme;
  #   };
  #   gtk3.extraConfig = {
  #     gtk-application-prefer-dark-theme = 1;
  #   };
  #   gtk4.extraConfig = {
  #     gtk-application-prefer-dark-theme = 1;
  #   };
  # };
  qt = {
    enable = true;
    platform = "adwita";
  };
}
