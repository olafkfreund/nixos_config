{
  pkgs,
  lib,
  config,
  ...
}: {
  options.modules.desktop.hyprland-uwsm = {
    enable = lib.mkEnableOption "Hyprland with UWSM integration";
  };

  config = lib.mkIf config.modules.desktop.hyprland-uwsm.enable {
    # Enable the Hyprland window manager itself
    programs.hyprland = {
      enable = true;
      # Enable experimental features, including UWSM
      package = null; # Using the Home Manager package instead
      # Enable XWayland for compatibility
      xwayland.enable = true;
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
          default = ["hyprland" "gtk"];
        };
        hyprland = {
          default = ["hyprland" "gtk"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
          "org.freedesktop.impl.portal.Screencast" = ["hyprland"];
        };
      };
    };

    # Ensure the polkit authentication agent is available
    security.polkit.enable = true;

    # Set up necessary environment variables for UWSM
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      XCURSOR_SIZE = "24";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    # Make sure required packages are available
    environment.systemPackages = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
}
