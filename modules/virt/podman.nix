{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.podman;
in {
  options.services.podman = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the Podman service.";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      podman-compose
      podman-tui
      podman-desktop
      podman
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
