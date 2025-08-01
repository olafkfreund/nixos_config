{pkgs, ...}: let
  vars = import ../variables.nix;
in {
  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${vars.theme.scheme}.yaml";
    image = vars.theme.wallpaper;

    # Font configuration
    fonts = {
      monospace = {
        # Use the specific nerd-fonts package to ensure proper icons
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = vars.theme.font.mono;
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = vars.theme.font.sans;
      };
      serif = {
        package = pkgs.noto-fonts;
        name = vars.theme.font.serif;
      };
    };

    # Font sizes
    fonts.sizes = vars.theme.font.sizes;

    # Opacity settings
    opacity = vars.theme.opacity;

    cursor = {
      name = vars.theme.cursor.name;
      package = pkgs.bibata-cursors;
      size = vars.theme.cursor.size;
    };

    # Target-specific configuration
    targets = {
      chromium.enable = false; # Exclude browser theming
      firefox.enable = false; # Disable Firefox theming to avoid warnings
      qt.enable = false; # Disable Qt theming to avoid GNOME platform warnings
    };
  };
}
