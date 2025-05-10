{
  config,
  lib,
  pkgs,
  ...
}: {
  # Fix for Qt platform theme integration
  qt = {
    enable = true;
    platformTheme = lib.mkForce "gnome"; # Valid value for platform theme integration
    style = lib.mkForce "adwaita"; # Force this value to override other definitions
  };

  # Make sure the adwaita-qt package is installed
  environment.systemPackages = [pkgs.adwaita-qt];
}
