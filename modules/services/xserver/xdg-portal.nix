{ pkgs
, ...
}: {
  # ------------------------------------------
  # XDG Desktop Portal integration
  # ------------------------------------------

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      common = {
        default = "*";
        "org.freedesktop.impl.portal.Screencast" = "hyprland";
        "org.freedesktop.impl.portal.Screenshot" = "hyprland";
      };
    };
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal
      xdg-desktop-portal-wlr
      xdg-desktop-portal-hyprland
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal
    ];
  };
}
