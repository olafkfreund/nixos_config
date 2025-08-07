{ pkgs
, lib
, config
, ...
}:
with lib; let
  cfg = config.modules.desktop.hyprland-uwsm;
in
{
  options.modules.desktop.hyprland-uwsm = {
    enable = mkEnableOption "Hyprland with UWSM integration";
  };

  config = mkIf cfg.enable {
    # Enable the Hyprland window manager itself
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      package = pkgs.hyprland;
    };

    # Enable the necessary services for UWSM
    systemd.packages = with pkgs; [
      hyprland
    ];

    # Proper XDG Portal setup for Hyprland
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          default = [ "hyprland" "gtk" ];
        };
        hyprland = {
          default = [ "hyprland" "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
          "org.freedesktop.impl.portal.Screencast" = [ "hyprland" ];
        };
      };
    };

    # Ensure the polkit authentication agent is available
    security.polkit.enable = true;

    # Set up necessary environment variables for UWSM
    environment.sessionVariables = {
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    # Make sure required packages are available
    environment.systemPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
}
