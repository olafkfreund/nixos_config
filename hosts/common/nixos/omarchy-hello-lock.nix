# hello-lock: lock-screen plugin for the Omarchy shell (#2631), enabled once per host.
# Upgrade by bumping rev + hash in pkgs/hello-lock, never `omarchy plugin update`.
{ pkgs, ... }:
{
  imports = [ ./omarchy-enable-once.nix ];

  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins.hello-lock.src = "${pkgs.customPkgs.hello-lock}/share/hello-lock/plugin";
    local.omarchy.enableOnce = [ "hello-lock" ];
  };
}
