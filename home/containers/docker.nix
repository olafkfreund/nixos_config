{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    docker-compose
    docker
    docui
    docker-gc
    lazydocker
   ];

  #Docker config
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  programs = {
    };
}
