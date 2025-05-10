{
  lib,
  pkgs,
  ...
}: {
  # Qt platform theme integration
  qt = {
    enable = true;
    platformTheme = lib.mkForce "gnome";
  };

  # Make sure the adwaita-qt packages are installed
  environment.systemPackages = with pkgs; [
    adwaita-qt
    adwaita-qt6
  ];
}
