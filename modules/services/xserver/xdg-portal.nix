# XDG Desktop Portal Configuration Module
# Configures desktop integration for Wayland and X11 applications
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.services.xdg-portal;
in {
  options.modules.services.xdg-portal = {
    enable = mkEnableOption "XDG desktop portal services";

    backend = mkOption {
      type = types.enum ["hyprland" "sway" "gnome" "kde"];
      default = "hyprland";
      description = ''Primary desktop environment backend for portals'';
      example = "sway";
    };

    enableScreencast = mkOption {
      type = types.bool;
      default = true;
      description = ''Enable screencasting support through portals'';
      example = false;
    };

    suppressIconWarning = mkOption {
      type = types.bool;
      default = true;
      description = ''Suppress XDG icon protocol warnings'';
      example = false;
    };

    forcePortalOpen = mkOption {
      type = types.bool;
      default = true;
      description = ''Force applications to use portal for file operations'';
      example = false;
    };
  };

  config = mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = cfg.forcePortalOpen;
      
      config = mkMerge [
        # Common configuration for all backends
        {
          common = {
            default = [cfg.backend "gtk"];
          };
        }
        
        # Hyprland-specific configuration
        (mkIf (cfg.backend == "hyprland") {
          hyprland = {
            default = ["hyprland" "gtk"];
            "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
          } // optionalAttrs cfg.enableScreencast {
            "org.freedesktop.impl.portal.Screencast" = ["hyprland"];
          };
        })
        
        # Sway-specific configuration
        (mkIf (cfg.backend == "sway") {
          sway = {
            default = ["wlr" "gtk"];
          } // optionalAttrs cfg.enableScreencast {
            "org.freedesktop.impl.portal.Screencast" = ["wlr"];
          };
        })
      ];
      
      configPackages = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal
      ] ++ optionals (cfg.backend == "hyprland") [
        xdg-desktop-portal-hyprland
      ] ++ optionals (cfg.backend == "sway") [
        xdg-desktop-portal-wlr
      ] ++ optionals (cfg.backend == "gnome") [
        xdg-desktop-portal-gnome
      ] ++ optionals (cfg.backend == "kde") [
        xdg-desktop-portal-kde
      ];
    };

    # Optional environment variables
    environment.sessionVariables = mkIf cfg.suppressIconWarning {
      NO_XDG_ICON_WARNING = "1";
    };

    # Validation
    assertions = [
      {
        assertion = cfg.enableScreencast -> (cfg.backend == "hyprland" || cfg.backend == "sway");
        message = "Screencasting is currently only supported with Hyprland and Sway backends";
      }
    ];

    # Helpful warnings
    warnings = [
      (mkIf (cfg.backend == "sway" && cfg.enableScreencast) ''
        Sway screencasting requires xdg-desktop-portal-wlr.
        Ensure it's available in your system packages.
      '')
    ];
  };
}
