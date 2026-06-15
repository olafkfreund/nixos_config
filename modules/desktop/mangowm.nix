{ config, lib, ... }:
# mango — dwl-based (wlroots + scenefx) Wayland compositor, exposed as a
# selectable login session. The mango flake's NixOS module (programs.mango) is
# wired in flake.nix; this feature module just turns it on. programs.mango
# handles the rest — it installs share/wayland-sessions/mango.desktop (so
# greetd/GDM list "mango"), enables built-in XWayland, wlr/gtk portals and
# polkit. Session config (keybinds, env, autostart) lands in the Noctalia home
# profile, the same place niri/labwc are configured.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.desktop.mangowm;
in
{
  options.desktop.mangowm.enable =
    mkEnableOption "mango dwl-based Wayland compositor (selectable login session)";

  config = mkIf cfg.enable {
    programs.mango.enable = true;
  };
}
