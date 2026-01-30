{ pkgs
, lib
, ...
}:
let
  vars = import ../variables.nix { };
in
{
  # Stylix theming
  stylix = {
    enable = true;
    enableReleaseChecks = false; # Disable version mismatch warnings
    polarity = "dark";
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${vars.theme.scheme}.yaml";
    image = vars.theme.wallpaper;

    # Font configuration
    fonts = {
      monospace = {
        # Use Adwaita Mono (built into GNOME)
        package = pkgs.gnome-themes-extra;
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

    # Font sizes (adjusted for better readability)
    fonts.sizes = vars.theme.font.sizes;

    # Opacity settings
    inherit (vars.theme) opacity;

    cursor = {
      inherit (vars.theme.cursor) name size;
      package = pkgs.bibata-cursors;
    };

    # Target-specific configuration
    targets = {
      chromium.enable = false; # Exclude browser theming
      gnome.enable = false; # Disable GNOME theming - let Home Manager handle it
      gtk.enable = false; # Let COSMIC manage GTK theming at runtime
      qt = {
        enable = true; # Enable Qt theming for consistent styling
        platform = lib.mkForce "qtct"; # Use qtct platform (supported by stylix)
      };
    };
  };
}
