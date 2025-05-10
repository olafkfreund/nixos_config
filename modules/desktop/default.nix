{
  config,
  lib,
  pkgs,
  ...
}: {
  # Fix for deprecated 'gnome' Qt platform theme
  qt = {
    enable = true;
    platformTheme = {
      name = lib.mkForce "adwaita"; # Use the recommended value instead of deprecated 'gnome'
    };
    style = {
      name = "adwaita";
      package = pkgs.adwaita-qt;
    };
  };
}
