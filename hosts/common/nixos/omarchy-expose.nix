# Exposé: window overview on SUPER+E, declared in omarchy-keys.nix. Installed and
# enabled once per host; turning it off in Setup > Plugins sticks. The hot corner
# is off by package default (#2723).
{ config, pkgs, ... }:
let
  id = "expose.window-overview";
in
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins.${id}.src =
      pkgs.customPkgs.expose-plugin.override { hyprland = config.programs.hyprland.package; };

    local.omarchy.enableOnce = [ id ];
  };
}
