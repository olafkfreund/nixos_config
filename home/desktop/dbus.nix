{pkgs, ...}: {
  services.dbus = {
    enable = true;
    packages = with pkgs; [
      dconf
      gnome2.GConf
      xdg-desktop-portal
      xdg-desktop-portal-hyprland
    ];
  };
}
