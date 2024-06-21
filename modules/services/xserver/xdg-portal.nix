{ pkgs
, ...
}: {
  # ------------------------------------------
  # XDG Desktop Portal integration
  # ------------------------------------------

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common.default = [ "gnome" ];
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal
    ];
  };
}
