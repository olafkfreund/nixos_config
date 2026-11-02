# Omaoutlook: Microsoft Outlook web in an Omarchy-themed window (#2602). The
# host app is built by Nix and starts hidden at login; the plugin is enabled
# once per host by the shared post-boot hook. Sign in to Outlook once per host:
# the login lives in ~/.local/share/omaoutlook and stays yours.
# Upgrade by bumping rev + hash in pkgs/omaoutlook, never `omarchy plugin update`.
{ config, pkgs, ... }:
let
  omateams = pkgs.customPkgs.omateams.override { hyprland = config.programs.hyprland.package; };
  omaoutlook = pkgs.customPkgs.omaoutlook.override {
    inherit omateams;
    hyprland = config.programs.hyprland.package;
  };
in
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins.omaoutlook.src = "${omaoutlook}/share/omaoutlook/plugin";
    home.packages = [ omaoutlook ];
    local.omarchy.enableOnce = [ "omaoutlook" ];
  };
}
