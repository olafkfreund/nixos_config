{ config, lib, pkgs, ... }:
# Hyprland — dynamic-tiling Wayland compositor, exposed as a selectable login
# session alongside niri/labwc/mango. Hyprland 0.55+ dropped hyprlang in favour
# of an embedded Lua runtime, so the config is ~/.config/hypr/hyprland.lua,
# written by home-manager (see home/desktop/hyprland).
#
# programs.hyprland ships its own share/wayland-sessions/hyprland.desktop, so
# unlike labwc/mango no session file is generated here; the DMS variant lives in
# dms-shell.nix.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.desktop.hyprland;
in
{
  options.desktop.hyprland.enable =
    mkEnableOption "Hyprland dynamic-tiling Wayland compositor (selectable login session)";

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      xwayland.enable = true;
      # Explicit rather than relying on the default: portal routing is the usual
      # failure mode when adding a compositor here (stale XDG_CURRENT_DESKTOP
      # sends ScreenCast to the wrong backend).
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };
  };
}
