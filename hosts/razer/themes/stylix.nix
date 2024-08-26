{ pkgs
, ...
}: {
  # Stylix theming
  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    image = ./gruv-abstract-maze.png;

    # Font configuration
    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];};
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
    };

    # Font sizes (adjust as needed)
    fonts.sizes = {
      applications = 12;
      terminal = 13; # Slightly larger for better readability in terminal
      desktop = 12;
      popups = 11; # Slightly smaller for popups
    };

    # Opacity settings
    opacity = {
      applications = 1.0;
      terminal = 0.95; # Slight transparency for terminal
      desktop = 1.0;
      popups = 0.98; # Slight transparency for popups
    };

    # Cursor settings
    cursor = {
      name = "Bibata-Modern-Ice";
      size = 26;
    };

    # Exclude specific targets
    targets.chromium.enable = false; # Exclude browser theming
  };
}
