{pkgs, ...}: {
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
  # hardware.nvidia-container-toolkit.enable = true;
  users.users.olafkfreund.extraGroups = ["docker"];
  # virtualisation.docker.rootless = {
  #   enable = false;
  #   setSocketVariable = false;
  # };
  # virtualisation.docker.enableOnBoot = true;
  # systemd.enableUnifiedCgroupHierarchy = false;
}
