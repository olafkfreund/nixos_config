{ config, lib, ... }:
# mango — dwl-based (wlroots + scenefx) Wayland compositor, exposed as a
# selectable login session. programs.mango comes from nixpkgs; this feature
# module just turns it on. programs.mango handles the rest — it installs
# share/wayland-sessions/mango.desktop (so greetd/GDM list "mango") and wires
# the wlr/gtk portals. Session config (keybinds, env, autostart) lands in the
# Noctalia home profile, the same place niri/labwc are configured.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.desktop.mangowm;
in
{
  options.desktop.mangowm.enable =
    mkEnableOption "mango dwl-based Wayland compositor (selectable login session)";

  config = mkIf cfg.enable {
    programs.mango.enable = true;
    # nixpkgs' programs.mango module doesn't set these; the mango flake's module
    # (which we no longer import) did, and mango needs both: XWayland for X11
    # clients, and the wlr portal backend it routes ScreenCast/Screenshot to.
    programs.xwayland.enable = true;
    xdg.portal.wlr.enable = true;
  };
}
