{ pkgs
, ...
}: {
  # ------------------------------------------
  # XDG Desktop Portal integration
  # ------------------------------------------

  xdg.portal = {
    enable = true;
    # xdgOpenUsePortal = true;
     # gtkUsePortal = true;
    # config = {
    #   common = {
    #     default = [ "gtk" ];
    #     "org.freedesktop.impl.portal.Screencast" = "hyprland";
    #     "org.freedesktop.impl.portal.Screenshot" = "hyprland";
    #     "org.freedesktop.impl.portal.OpenURI" = "gtk";
    #    };
    # };
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      xdg-desktop-portal
    ];
  };
}
