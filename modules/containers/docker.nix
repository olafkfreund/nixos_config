{
  config,
  lib,
  pkgs,
  hostUsers ? [],
  ...
}: let
  cfg = config.modules.containers.docker;
in {
  options.modules.containers.docker = {
    enable = lib.mkEnableOption "Docker container support";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = hostUsers; # Use host users as default
      description = "List of users to add to the docker group";
      example = ["olafkfreund" "workuser"];
    };

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable rootless Docker";
    };
  };

  config = lib.mkIf cfg.enable {
    # Docker packages
    environment.systemPackages = with pkgs; [
      docker-compose
      docker-client
      docui
      docker-gc
      lazydocker
      earthly
    ];

    # Docker configuration
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      rootless = {
        enable = cfg.rootless;
        setSocketVariable = cfg.rootless;
      };
    };

    # Add specified users to docker group
    users.users = lib.genAttrs cfg.users (username: {
      extraGroups = ["docker"];
    });

    # Validation
    assertions = [
      {
        assertion = cfg.rootless -> (cfg.users != []);
        message = "Rootless Docker requires at least one user to be specified";
      }
      {
        assertion = !cfg.rootless -> (builtins.all (user: user != "root") cfg.users);
        message = "Root user should not be added to docker group in non-rootless mode";
      }
    ];

    # Helpful warnings
    warnings = [
      (lib.mkIf (cfg.enable && !cfg.rootless && cfg.users == []) ''
        Docker is enabled but no users are specified.
        Users won't be able to use Docker without being manually added to the docker group.
      '')
      (lib.mkIf (cfg.rootless && cfg.users != []) ''
        Rootless Docker is enabled. Users will have their own Docker daemon instances.
        Consider the security implications and resource usage.
      '')
    ];
  };
}
