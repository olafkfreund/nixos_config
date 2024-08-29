{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: 
with lib; let
  cfg = config.services.docker;
in {
  options.services.docker = {
    enable = mkEnableOption {
      description = "Enable Docker";
      default = false;
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      docker-compose
      docker-client
      docui
      docker-gc
      nerdctl
      lazydocker
      nvidia-docker
      arion
      nvidia-container-toolkit
    ];
    #Docker config
    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = false;
        setSocketVariable = false;
      };
      enableOnBoot = true;
    };
    users.users.olafkfreund.extraGroups = ["docker"];
  };
}
