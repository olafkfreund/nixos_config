{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.desktop.hyprland;
in {
  options.modules.desktop.hyprland = {
    enable = lib.mkEnableOption "Enable Hyprland window manager with appropriate configuration";
  };

  config = lib.mkIf cfg.enable {
    # Enable Hyprland system configuration
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Proper XDG Portal setup for Hyprland
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-hyprland];
      config = {
        common = {
          default = ["hyprland" "gtk"];
        };
        hyprland = {
          default = ["hyprland" "gtk"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
          "org.freedesktop.impl.portal.Screencast" = ["hyprland"];
        };
      };
    };

    # Make sure required packages are available
    environment.systemPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];

    # Enable polkit for authentication
    security.polkit.enable = true;
  };
}
