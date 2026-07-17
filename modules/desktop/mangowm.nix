{ config, lib, pkgs, inputs, ... }:
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
    # mango's meson.build requires scenefx-0.5, but its flake builds the package
    # against scenefx 0.4.1. Rebuild the mango package with the scenefx 0.5 we
    # pin in flake.nix. Drop this override once mango wires scenefx 0.5 upstream.
    programs.mango.package =
      inputs.mango.packages.${pkgs.stdenv.hostPlatform.system}.mango.override {
        scenefx = inputs.scenefx.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
  };
}
