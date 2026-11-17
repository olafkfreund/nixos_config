# Pocket: Omarchy bar plugin that hides widgets behind one mark until hovered. The
# hidden widgets stay loaded, so they show instantly. Replaced Shelfish, whose shelves
# reloaded every widget on each open.
# Upgrade by bumping rev + hash in pkgs/omarchy-pocket, never `omarchy plugin update`.
{ pkgs, ... }:
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins."jrmmhm.pocket".src = "${pkgs.customPkgs.omarchy-pocket}/share/omarchy-pocket/plugin";
    local.omarchy.enableOnce = [ "jrmmhm.pocket" ];
  };
}
