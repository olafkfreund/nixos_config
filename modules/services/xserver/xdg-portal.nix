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
      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
      };
    };
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      # xdg-desktop-portal-wlr
      # xdg-desktop-portal
    ];
  };

  # Add environment variable to disable icon protocol warning
  environment.sessionVariables = {
    # Suppress XDG toplevel icon protocol warnings
    XDG_CURRENT_DESKTOP = "Hyprland";
    NIXOS_OZONE_WL = "1";
    WAYLAND_DEBUG = "suppress";
    NO_XDG_ICON_WARNING = "1";
  };
}
