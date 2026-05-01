{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.services.podman;
in
{
  options.services.podman = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the Podman service.";
    };
  };
  config = mkIf cfg.enable {
    # podman itself is installed by virtualisation.podman.enable (below)
    # with the systemd integration wrapper. Listing pkgs.podman here would
    # collide against that wrapper in buildEnv.
    environment.systemPackages = with pkgs; [
      podman-compose
      podman-tui
      podman-desktop
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
