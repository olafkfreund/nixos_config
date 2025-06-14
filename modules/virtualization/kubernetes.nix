{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.virtualization.kubernetes = {
    enable = lib.mkEnableOption "Kubernetes support";

    kubectl = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable kubectl command-line tool";
    };

    minikube = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Minikube for local development";
    };

    k3s = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable K3s lightweight Kubernetes";
    };

    helm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Helm package manager";
    };
  };

  config = lib.mkIf config.modules.virtualization.kubernetes.enable {
    environment.systemPackages = with pkgs;
      lib.flatten [
        (lib.optionals config.modules.virtualization.kubernetes.kubectl [
          kubectl
          kubectx
          kubens
        ])
        (lib.optionals config.modules.virtualization.kubernetes.minikube [
          minikube
        ])
        (lib.optionals config.modules.virtualization.kubernetes.helm [
          kubernetes-helm
        ])
      ];

    services.k3s = lib.mkIf config.modules.virtualization.kubernetes.k3s {
      enable = true;
      role = "server";
    };

    # Enable Docker for Minikube
    virtualisation.docker.enable = lib.mkIf config.modules.virtualization.kubernetes.minikube true;

    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = lib.optionals config.modules.virtualization.kubernetes.minikube ["docker"];
      })
    ];
  };
}
