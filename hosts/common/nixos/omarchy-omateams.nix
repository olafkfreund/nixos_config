# Omateams: Microsoft Teams web in an Omarchy-themed window (#2505). The host
# app is built by Nix and starts hidden at login; the plugin is enabled once
# per host by the shared post-boot hook. Sign in to Teams once per host: the
# login lives in ~/.local/share/omateams and stays yours.
# Upgrade by bumping rev + hash in pkgs/omateams, never `omarchy plugin update`.
{ config, pkgs, ... }:
let
  omateams = pkgs.customPkgs.omateams.override { hyprland = config.programs.hyprland.package; };
in
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins.omateams.src = "${omateams}/share/omateams/plugin";
    home.packages = [ omateams ];
    local.omarchy.enableOnce = [ "omateams" ];
  };
}
