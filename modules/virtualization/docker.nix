{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.virtualization.docker = {
    enable = lib.mkEnableOption "Docker containerization";

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable rootless Docker";
    };

    nvidia = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA container runtime";
    };

    buildx = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Docker Buildx";
    };

    compose = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Docker Compose";
    };
  };

  config = lib.mkIf config.modules.virtualization.docker.enable {
    virtualisation.docker = {
      enable = true;
      rootless = lib.mkIf config.modules.virtualization.docker.rootless {
        enable = true;
        setSocketVariable = true;
      };
      enableNvidia = config.modules.virtualization.docker.nvidia;
    };

    environment.systemPackages = with pkgs;
      [
        docker
        docker-machine
      ]
      ++ lib.optionals config.modules.virtualization.docker.buildx [
        docker-buildx
      ]
      ++ lib.optionals config.modules.virtualization.docker.compose [
        docker-compose
      ];

    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["docker"];
      })
    ];
  };
}
