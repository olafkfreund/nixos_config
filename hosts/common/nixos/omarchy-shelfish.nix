# Shelfish: Omarchy bar plugin that groups widgets into named shelves (only the
# open shelf's widgets load). Replaces the hand-installed Bar Folder.
# Upgrade by bumping rev + hash in pkgs/shelfish, never `omarchy plugin update`.
{ pkgs, ... }:
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins."io.github.patrickfanella.shelfish".src = "${pkgs.customPkgs.shelfish}/share/shelfish/plugin";
    local.omarchy.enableOnce = [ "io.github.patrickfanella.shelfish" ];
  };
}
