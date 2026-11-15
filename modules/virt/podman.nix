{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.virtualization;
in
{
  config = mkIf (cfg.enable && cfg.podman) {
    # podman itself is installed by virtualisation.podman.enable (below)
    # with the systemd integration wrapper. Listing pkgs.podman here would
    # collide against that wrapper in buildEnv.
    environment.systemPackages = with pkgs; [
      podman-compose
      podman-tui
      pods
    ];
    virtualisation = {
      podman = {
        enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
}
