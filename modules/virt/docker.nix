{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-client
    docui
    docker-gc
    lazydocker
   ];

  #Docker config
  virtualisation.docker.enable = true;
  users.users.olafkfreund.extraGroups = [ "docker" ];
  virtualisation.docker.rootless = {
    enable = false;
    setSocketVariable = true;
  };
  virtualisation.docker.enableOnBoot = true;
  programs = {
    };
}
