{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-client
    docui
    docker-gc
    nerdctl
    lazydocker
    nvidia-container-toolkit
    nvidia-docker
    arion
    nvidia-container-toolkit
  ];

  #Docker config
  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
    rootless = {
      enable = false;
      setSocketVariable = false;
    };
    enableOnBoot = true;
  };

  users.users.olafkfreund.extraGroups = ["docker"];
  # virtualisation.docker.rootless = {
  #   enable = false;
  #   setSocketVariable = false;

  # };
  # virtualisation.docker.enableOnBoot = true;
  systemd.enableUnifiedCgroupHierarchy = false;
  programs = {
  };
}
