{
  config,
  pkgs,
  host,
  username,
  lib,
  ...
}: let
  inherit
    (
      import ../../../../hosts/${host}/variables.nix
    )
    laptop_monitor
    external_monitor
    ;
in {
  wayland.windowManager.hyprland.extraConfig = ''
    ${laptop_monitor}
    ${external_monitor}
  '';
}
