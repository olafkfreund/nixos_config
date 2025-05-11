# modules/desktop/wayland/sway/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.sway;
in {
  options.desktop.sway = {
    enable = mkEnableOption "Sway window manager with standardized configuration";

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install with Sway";
    };
  };

  config = mkIf cfg.enable {
    # Enable Wayland environment variables
    wayland-environment.enable = true;

    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs;
        [
          swaylock
          swayidle
          swaycons
          wl-clipboard
          grim
          slurp
          foot
          dmenu
        ]
        ++ cfg.extraPackages;
    };

    programs.light.enable = true;

    # Ensure XDG portal works correctly
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };

    # Sunshine remote desktop wrapper with proper capabilities
    security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
    };

    # Disable network wait services to speed up boot time
    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
    systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  };
}
