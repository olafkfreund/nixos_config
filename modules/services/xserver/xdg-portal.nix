{pkgs, ...}: {
  xdg.portal = {
    enable = true;
    # wlr.enable = false;
    xdgOpenUsePortal = true;
    # extraPortals = with pkgs; [
    #   xdg-desktop-portal
    # ];
    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
    };
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      # xdg-desktop-portal-wlr
      # xdg-desktop-portal
    ];
  };
}
