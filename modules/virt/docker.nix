{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-client
    docui
    docker-gc
    nerdctl
    lazydocker
    nvidia-container-toolkit
    nvidia-docker

   ];

  #Docker config
  virtualisation.docker.enable = true;
  virtualisation.docker.enableNvidia = true;
  users.users.olafkfreund.extraGroups = [ "docker" ];
  virtualisation.docker.rootless = {
    enable = false;
    setSocketVariable = false;

  };
  virtualisation.docker.enableOnBoot = true;
  systemd.enableUnifiedCgroupHierarchy = false;
  programs = {
    };
}
