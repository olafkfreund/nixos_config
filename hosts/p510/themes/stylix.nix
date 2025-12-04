{ pkgs, lib, ... }:
let
  vars = import ../variables.nix { };
in
{
  stylix = {
    enable = true;
    enableReleaseChecks = false; # Disable version mismatch warnings
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${vars.theme.scheme}.yaml";
    image = vars.theme.wallpaper;
    polarity = "dark";
    targets = {
      chromium.enable = false;
      qt = {
        enable = true; # Enable Qt theming for consistent styling
        platform = lib.mkForce "qtct"; # Use qtct platform (supported by stylix)
      };
    };
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
      sizes = vars.theme.font.sizes;
    };
    opacity = vars.theme.opacity;
    cursor = {
      name = vars.theme.cursor.name;
      package = pkgs.bibata-cursors;
      size = vars.theme.cursor.size;
    };
  };
}
